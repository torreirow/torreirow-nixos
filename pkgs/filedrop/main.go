package main

import (
	"bytes"
	_ "embed"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"net/mail"
	"net/url"
	"os"
	"path"
	"strconv"
	"strings"
	"time"
	"unicode"
)

//go:embed index.html
var indexHTML string

var (
	capURL        string // https://cap.example/<site-key>
	capSecret     string
	davBase       string // https://nextcloud/public.php/dav/files/<share-token>
	signalAPI     string
	signalSender  string
	signalTo      string
	contact       string // shown to uploaders whose files exceed the limit
	maxBytes      int64
	page          []byte
	davClient     = &http.Client{}
	shortClient   = &http.Client{Timeout: 15 * time.Second}
	amsterdam, _  = time.LoadLocation("Europe/Amsterdam")
	errValidation = errors.New("validation")
)

func mustEnv(name string) string {
	v := strings.TrimSpace(os.Getenv(name))
	if v == "" {
		log.Fatalf("environment variable %s is required", name)
	}
	return v
}

func main() {
	port := mustEnv("FILEDROP_PORT")
	capURL = strings.TrimRight(mustEnv("CAP_URL"), "/")
	capSecret = mustEnv("CAP_SECRET")
	davBase = strings.TrimRight(mustEnv("NEXTCLOUD_URL"), "/") + "/public.php/dav/files/" + mustEnv("NEXTCLOUD_SHARE_TOKEN")
	signalAPI = mustEnv("SIGNAL_API")
	signalSender = mustEnv("SIGNAL_SENDER")
	signalTo = mustEnv("SIGNAL_RECIPIENT")
	contact = mustEnv("LARGE_FILE_CONTACT")
	var err error
	if maxBytes, err = strconv.ParseInt(mustEnv("MAX_BYTES"), 10, 64); err != nil {
		log.Fatalf("MAX_BYTES: %v", err)
	}
	if amsterdam == nil {
		amsterdam = time.UTC
	}
	limits = loadLimits()

	page = []byte(strings.NewReplacer(
		"{{CAP_ENDPOINT}}", capURL+"/",
		"{{MAX_MB}}", strconv.FormatInt(maxBytes>>20, 10),
		"{{CONTACT}}", contact,
	).Replace(indexHTML))

	addr := "127.0.0.1:" + port
	log.Printf("filedrop listening on %s (max %d MB per upload)", addr, maxBytes>>20)

	mux := http.NewServeMux()
	mux.HandleFunc("/", handleIndex)
	mux.HandleFunc("/upload", handleUpload)
	log.Fatal(http.ListenAndServe(addr, mux))
}

func handleIndex(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write(page)
}

func writeJSON(w http.ResponseWriter, status int, ok bool, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]any{"ok": ok, "message": msg})
}

// upload holds the state of one form submission. Text fields precede the file
// input in the form, so they are known before the first file part arrives and
// everything is validated before a single byte goes to Nextcloud.
type upload struct {
	fields    map[string]string
	ip        string
	slot      int64 // reserved quota slot, 0 until validated
	validated bool
	folder    string
	files     []string
	bytes     int64
}

func handleUpload(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, false, "Ongeldig verzoek.")
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxBytes)
	mr, err := r.MultipartReader()
	if err != nil {
		writeJSON(w, http.StatusBadRequest, false, "Ongeldig verzoek.")
		return
	}

	ip := r.Header.Get("X-Real-IP")
	if ip == "" {
		ip = r.RemoteAddr
	}
	u := &upload{fields: map[string]string{}, ip: ip}
	for {
		part, err := mr.NextPart()
		if err == io.EOF {
			break
		}
		if err != nil {
			fail(w, u, err)
			return
		}
		if part.FileName() == "" {
			v, _ := io.ReadAll(io.LimitReader(part, 4096))
			u.fields[part.FormName()] = strings.TrimSpace(string(v))
			continue
		}
		if err := u.validate(); err != nil {
			fail(w, u, err)
			return
		}
		if u.fields["website"] != "" { // honeypot: pretend success, store nothing
			writeJSON(w, http.StatusOK, true, "Bedankt!")
			return
		}
		if err := u.store(r, part); err != nil {
			fail(w, u, err)
			return
		}
	}

	if len(u.files) == 0 {
		if err := u.validate(); err != nil {
			fail(w, u, err)
			return
		}
		writeJSON(w, http.StatusBadRequest, false, "Kies minstens één bestand.")
		return
	}

	account(u.slot, u.bytes)
	log.Printf("upload ok: %d file(s), %d bytes into %q", len(u.files), u.bytes, u.folder)
	notify(fmt.Sprintf("📥 Nieuwe upload via upload.toorren.net\nVan: %s <%s>\nBestanden (%d, %s):\n- %s\nMap: %s",
		u.fields["naam"], u.fields["email"], len(u.files), human(u.bytes),
		strings.Join(u.files, "\n- "), u.folder))
	writeJSON(w, http.StatusOK, true, fmt.Sprintf("Bedankt! %d bestand(en) ontvangen.", len(u.files)))
}

func fail(w http.ResponseWriter, u *upload, err error) {
	if u.slot != 0 {
		account(u.slot, u.bytes)
	}
	var tooBig *http.MaxBytesError
	switch {
	case errors.As(err, &tooBig):
		writeJSON(w, http.StatusRequestEntityTooLarge, false,
			fmt.Sprintf("De upload is groter dan %d MB. Neem voor grotere bestanden contact op met %s.", maxBytes>>20, contact))
	case errors.Is(err, errValidation):
		writeJSON(w, http.StatusBadRequest, false, strings.TrimPrefix(err.Error(), "validation: "))
	default:
		log.Printf("upload failed after %d file(s) in %q: %v", len(u.files), u.folder, err)
		if len(u.files) > 0 {
			notify(fmt.Sprintf("⚠️ Upload van %s <%s> afgebroken na %d bestand(en): %v",
				u.fields["naam"], u.fields["email"], len(u.files), err))
		}
		writeJSON(w, http.StatusBadGateway, false, "Er ging iets mis bij het opslaan. Probeer het later opnieuw.")
	}
}

func (u *upload) validate() error {
	if u.validated {
		return nil
	}
	naam := u.fields["naam"]
	if naam == "" || len(naam) > 100 {
		return fmt.Errorf("%w: Vul je naam in.", errValidation)
	}
	addr, err := mail.ParseAddress(u.fields["email"])
	if err != nil || addr.Name != "" || !strings.Contains(addr.Address, ".") {
		return fmt.Errorf("%w: Vul een geldig e-mailadres in.", errValidation)
	}
	if !verifyCap(u.fields["cap-token"]) {
		return fmt.Errorf("%w: Captcha-verificatie mislukt. Probeer het opnieuw.", errValidation)
	}
	slot, err := reserve(u.ip)
	if err != nil {
		return err
	}
	u.slot = slot
	u.validated = true
	return nil
}

// store streams one file part into the share, inside a folder per submission.
func (u *upload) store(r *http.Request, part *multipart.Part) error {
	if u.folder == "" {
		base := fmt.Sprintf("%s - %s (%s)", time.Now().In(amsterdam).Format("2006-01-02 15.04"),
			clean(u.fields["naam"]), clean(u.fields["email"]))
		folder, err := mkcol(r, base)
		if err != nil {
			return err
		}
		u.folder = folder
	}

	name := clean(path.Base(strings.ReplaceAll(part.FileName(), "\\", "/")))
	if name == "" || name == "." {
		name = fmt.Sprintf("bestand-%d", len(u.files)+1)
	}
	body := &counter{r: part}
	req, err := http.NewRequestWithContext(r.Context(), http.MethodPut, davURL(u.folder, name), body)
	if err != nil {
		return err
	}
	req.Header.Set("X-NC-Nickname", u.fields["naam"])
	resp, err := davClient.Do(req)
	if err != nil {
		return err
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusCreated && resp.StatusCode != http.StatusNoContent {
		return fmt.Errorf("PUT %s: HTTP %d", name, resp.StatusCode)
	}
	u.files = append(u.files, name)
	u.bytes += body.n
	return nil
}

// mkcol creates the submission folder, adding a suffix when the name is taken.
func mkcol(r *http.Request, base string) (string, error) {
	for i := 1; i <= 20; i++ {
		folder := base
		if i > 1 {
			folder = fmt.Sprintf("%s %d", base, i)
		}
		req, err := http.NewRequestWithContext(r.Context(), "MKCOL", davURL(folder), nil)
		if err != nil {
			return "", err
		}
		resp, err := shortClient.Do(req)
		if err != nil {
			return "", err
		}
		resp.Body.Close()
		switch resp.StatusCode {
		case http.StatusCreated:
			return folder, nil
		case http.StatusMethodNotAllowed: // folder exists
			continue
		default:
			return "", fmt.Errorf("MKCOL: HTTP %d", resp.StatusCode)
		}
	}
	return "", errors.New("MKCOL: no free folder name")
}

func davURL(elems ...string) string {
	escaped := make([]string, len(elems))
	for i, e := range elems {
		escaped[i] = url.PathEscape(e)
	}
	return davBase + "/" + strings.Join(escaped, "/")
}

// clean strips characters that Nextcloud or desktop sync clients reject.
func clean(s string) string {
	s = strings.Map(func(r rune) rune {
		if unicode.IsControl(r) || strings.ContainsRune(`/\:*?"<>|`, r) {
			return -1
		}
		return r
	}, s)
	s = strings.Trim(strings.TrimSpace(s), ".")
	if len(s) > 150 {
		s = s[:150]
	}
	return s
}

func verifyCap(token string) bool {
	if token == "" {
		return false
	}
	body, _ := json.Marshal(map[string]string{"secret": capSecret, "response": token})
	resp, err := shortClient.Post(capURL+"/siteverify", "application/json", bytes.NewReader(body))
	if err != nil {
		log.Printf("cap siteverify error: %v", err)
		return false
	}
	defer resp.Body.Close()
	var result struct {
		Success bool `json:"success"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		log.Printf("cap siteverify decode error (HTTP %d): %v", resp.StatusCode, err)
		return false
	}
	return result.Success
}

// notify is best-effort: a failing Signal API never fails the upload.
func notify(msg string) {
	body, _ := json.Marshal(map[string]any{
		"message": msg, "number": signalSender, "recipients": []string{signalTo},
	})
	resp, err := shortClient.Post(signalAPI, "application/json", bytes.NewReader(body))
	if err != nil {
		log.Printf("signal error: %v", err)
		return
	}
	resp.Body.Close()
	if resp.StatusCode >= 300 {
		log.Printf("signal error: HTTP %d", resp.StatusCode)
	}
}

type counter struct {
	r io.Reader
	n int64
}

func (c *counter) Read(p []byte) (int, error) {
	n, err := c.r.Read(p)
	c.n += int64(n)
	return n, err
}

func human(n int64) string {
	switch {
	case n >= 1<<30:
		return fmt.Sprintf("%.1f GB", float64(n)/(1<<30))
	case n >= 1<<20:
		return fmt.Sprintf("%.1f MB", float64(n)/(1<<20))
	default:
		return fmt.Sprintf("%d kB", n>>10)
	}
}
