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

// White EGH logo on transparency, from evangelischegemeente.org; shown on a dark band.
//
//go:embed logo.png
var logoPNG []byte

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
	renderPage    *strings.Replacer
	devHTML       string // dev.sh: re-read index.html from this path on every request
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

	// The widget talks to the Cap server directly; dev.sh points it at the real
	// server while verification goes to a local stand-in.
	widgetURL := strings.TrimRight(os.Getenv("CAP_WIDGET_URL"), "/")
	if widgetURL == "" {
		widgetURL = capURL
	}
	renderPage = strings.NewReplacer(
		"{{CAP_ENDPOINT}}", widgetURL+"/",
		"{{MAX_MB}}", strconv.FormatInt(maxBytes>>20, 10),
		"{{CONTACT}}", contact,
	)
	page = []byte(renderPage.Replace(indexHTML))
	devHTML = os.Getenv("FILEDROP_DEV_HTML")

	addr := "127.0.0.1:" + port
	log.Printf("filedrop listening on %s (max %d MB per upload)", addr, maxBytes>>20)

	mux := http.NewServeMux()
	mux.HandleFunc("/", handleIndex)
	mux.HandleFunc("/upload", handleUpload)
	mux.HandleFunc("/logo.png", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "image/png")
		w.Header().Set("Cache-Control", "public, max-age=86400")
		w.Write(logoPNG)
	})
	log.Fatal(http.ListenAndServe(addr, mux))
}

func handleIndex(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if devHTML != "" {
		if html, err := os.ReadFile(devHTML); err == nil {
			w.Write([]byte(renderPage.Replace(string(html))))
			return
		}
	}
	w.Write(page)
}

func writeJSON(w http.ResponseWriter, status int, ok bool, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]any{"ok": ok, "message": msg})
}

// upload holds the state of one form submission. Text fields (including the
// video links) precede the file input in the form, so they are known before
// the first file part arrives and everything is validated before a single
// byte goes to Nextcloud.
type upload struct {
	fields    map[string]string
	ip        string
	when      time.Time
	slot      int64 // reserved quota slot, 0 until validated
	validated bool
	links     []link
	dir       []string // month and submission folder, empty until created
	used      map[string]bool
	files     []string
	bytes     int64
}

// Names written by the service itself; uploaded files never take them.
const (
	senderFile  = "_afzender.txt"
	linksFile   = "video-links.txt"
	messageFile = "bericht.txt"
	maxMessage  = 1000 // characters
)

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
	u := &upload{
		fields: map[string]string{}, ip: ip, when: time.Now().In(amsterdam),
		used: map[string]bool{senderFile: true, linksFile: true, messageFile: true},
	}
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
			if u.validated && strings.HasPrefix(part.FormName(), "link") {
				// Links are validated at the first file; one arriving later would be lost.
				fail(w, u, fmt.Errorf("%w: Ongeldig verzoek: links moeten vóór de bestanden staan.", errValidation))
				return
			}
			v, _ := io.ReadAll(io.LimitReader(part, 8192)) // room for a 1000-character message
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

	if !u.validated {
		// No file parts: a links-only submission, or an empty one.
		links, err := parseLinks(u.fields)
		if err == nil && len(links) == 0 {
			err = fmt.Errorf("%w: Kies minstens één bestand of vul een link in.", errValidation)
		}
		if err == nil {
			err = u.validate()
		}
		if err != nil {
			fail(w, u, err)
			return
		}
		if u.fields["website"] != "" {
			writeJSON(w, http.StatusOK, true, "Bedankt!")
			return
		}
	}
	if err := u.finish(r); err != nil {
		fail(w, u, err)
		return
	}

	account(u.slot, u.bytes)
	folder := strings.Join(u.dir, "/")
	log.Printf("upload ok: %d file(s), %d bytes, %d link(s) into %q", len(u.files), u.bytes, len(u.links), folder)
	notify(u.summary())
	writeJSON(w, http.StatusOK, true, fmt.Sprintf("Bedankt! We hebben %s ontvangen. "+
		"Het Scherm Team bekijkt je inzending. Je kunt dit venster sluiten.", u.received()))
}

func fail(w http.ResponseWriter, u *upload, err error) {
	if u.slot != 0 {
		account(u.slot, u.bytes)
	}
	var tooBig *http.MaxBytesError
	switch {
	case errors.As(err, &tooBig):
		writeJSON(w, http.StatusRequestEntityTooLarge, false,
			fmt.Sprintf("Je bestanden zijn samen groter dan %d MB. Neem contact op met het Scherm Team "+
				"via %s, dan krijg je een persoonlijke link om ze te sturen.", maxBytes>>20, contact))
	case errors.Is(err, errValidation):
		writeJSON(w, http.StatusBadRequest, false, strings.TrimPrefix(err.Error(), "validation: "))
	default:
		folder := strings.Join(u.dir, "/")
		log.Printf("upload failed after %d file(s) in %q: %v", len(u.files), folder, err)
		if len(u.dir) > 0 {
			notify(fmt.Sprintf("⚠️ Upload van %s <%s> afgebroken na %d bestand(en) in %s: %v",
				u.fields["naam"], u.fields["email"], len(u.files), folder, err))
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
	links, err := parseLinks(u.fields)
	if err != nil {
		return err
	}
	if len([]rune(u.fields["bericht"])) > maxMessage {
		return fmt.Errorf("%w: Je bericht is te lang. Gebruik maximaal %d tekens.", errValidation, maxMessage)
	}
	if !verifyCap(u.fields["cap-token"]) {
		return fmt.Errorf("%w: De controle \"Ik ben geen robot\" is niet gelukt. Probeer het opnieuw.", errValidation)
	}
	slot, err := reserve(u.ip)
	if err != nil {
		return err
	}
	u.links = links
	u.slot = slot
	u.validated = true
	return nil
}

// ensureDir creates <YYYY-MM>/<YYYYMMDD-HHMMSS>/ on first use. The share is
// create-only (no PROPFIND), so "exists" is only visible as a 405 on MKCOL.
func (u *upload) ensureDir(r *http.Request) error {
	if len(u.dir) > 0 {
		return nil
	}
	month := u.when.Format("2006-01")
	if status, err := mkcol(r, month); err != nil {
		return err
	} else if status != http.StatusCreated && status != http.StatusMethodNotAllowed {
		return fmt.Errorf("MKCOL %s: HTTP %d", month, status)
	}
	base := u.when.Format("20060102-150405")
	for i := 1; i <= 20; i++ {
		sub := base
		if i > 1 {
			sub = fmt.Sprintf("%s-%d", base, i)
		}
		status, err := mkcol(r, month, sub)
		if err != nil {
			return err
		}
		switch status {
		case http.StatusCreated:
			u.dir = []string{month, sub}
			return nil
		case http.StatusMethodNotAllowed: // folder exists
			continue
		default:
			return fmt.Errorf("MKCOL %s/%s: HTTP %d", month, sub, status)
		}
	}
	return errors.New("MKCOL: no free folder name")
}

func mkcol(r *http.Request, elems ...string) (int, error) {
	req, err := http.NewRequestWithContext(r.Context(), "MKCOL", davURL(elems...), nil)
	if err != nil {
		return 0, err
	}
	resp, err := shortClient.Do(req)
	if err != nil {
		return 0, err
	}
	resp.Body.Close()
	return resp.StatusCode, nil
}

// uniqueName returns name, or "name (2).ext", "name (3).ext", ... when it is
// already used in this submission: the share does not allow overwriting.
func (u *upload) uniqueName(name string) string {
	ext := path.Ext(name)
	stem := strings.TrimSuffix(name, ext)
	candidate := name
	for i := 2; u.used[strings.ToLower(candidate)]; i++ {
		candidate = fmt.Sprintf("%s (%d)%s", stem, i, ext)
	}
	u.used[strings.ToLower(candidate)] = true
	return candidate
}

// store streams one file part into the submission folder.
func (u *upload) store(r *http.Request, part *multipart.Part) error {
	if err := u.ensureDir(r); err != nil {
		return err
	}
	name := clean(path.Base(strings.ReplaceAll(part.FileName(), "\\", "/")))
	if name == "" || name == "." {
		name = fmt.Sprintf("bestand-%d", len(u.files)+1)
	}
	name = u.uniqueName(name)
	body := &counter{r: part}
	if err := u.put(r, name, body); err != nil {
		return err
	}
	u.files = append(u.files, name)
	u.bytes += body.n
	return nil
}

func (u *upload) put(r *http.Request, name string, body io.Reader) error {
	elems := append(append([]string{}, u.dir...), name)
	req, err := http.NewRequestWithContext(r.Context(), http.MethodPut, davURL(elems...), body)
	if err != nil {
		return err
	}
	// No X-NC-Nickname header: on a File Drop, Nextcloud moves uploads that carry
	// a guest name into a folder named after that guest, breaking the layout.
	resp, err := davClient.Do(req)
	if err != nil {
		return err
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusCreated && resp.StatusCode != http.StatusNoContent {
		return fmt.Errorf("PUT %s: HTTP %d", name, resp.StatusCode)
	}
	return nil
}

// finish writes video-links.txt and _afzender.txt once all files are stored,
// so the sender file can list them.
func (u *upload) finish(r *http.Request) error {
	if err := u.ensureDir(r); err != nil {
		return err
	}
	if len(u.links) > 0 {
		fetchTitles(r.Context(), u.links)
		if err := u.put(r, linksFile, bytes.NewReader(renderLinks(u.links))); err != nil {
			return err
		}
	}
	// The message is only stored as a file; it never goes into the Signal notification.
	if msg := messageText(u.fields["bericht"]); msg != "" {
		if err := u.put(r, messageFile, strings.NewReader(msg)); err != nil {
			return err
		}
	}
	return u.put(r, senderFile, bytes.NewReader(u.senderText()))
}

// messageText keeps line breaks and tabs, drops other control characters and
// uses CRLF line endings; empty input gives "".
func messageText(s string) string {
	s = strings.ReplaceAll(strings.ReplaceAll(s, "\r\n", "\n"), "\r", "\n")
	s = strings.TrimSpace(strings.Map(func(r rune) rune {
		if unicode.IsControl(r) && r != '\n' && r != '\t' {
			return -1
		}
		return r
	}, s))
	if s == "" {
		return ""
	}
	return strings.ReplaceAll(s, "\n", "\r\n") + "\r\n"
}

// received describes the submission for the uploader, e.g. "2 bestanden en 1 link".
func (u *upload) received() string {
	count := func(n int, one, many string) string {
		if n == 1 {
			return "1 " + one
		}
		return fmt.Sprintf("%d %s", n, many)
	}
	var parts []string
	if len(u.files) > 0 {
		parts = append(parts, count(len(u.files), "bestand", "bestanden"))
	}
	if len(u.links) > 0 {
		parts = append(parts, count(len(u.links), "link", "links"))
	}
	return strings.Join(parts, " en ")
}

func (u *upload) senderText() []byte {
	lines := []string{
		"Naam: " + oneLine(u.fields["naam"]),
		"E-mail: " + oneLine(u.fields["email"]),
		"Tijdstip: " + u.when.Format("02-01-2006 15:04:05"),
		fmt.Sprintf("Bestanden (%d, %s):", len(u.files), human(u.bytes)),
	}
	for _, f := range u.files {
		lines = append(lines, "- "+f)
	}
	lines = append(lines, fmt.Sprintf("Links: %d (zie %s)", len(u.links), linksFile))
	return []byte(strings.Join(lines, "\r\n") + "\r\n")
}

func (u *upload) summary() string {
	var b strings.Builder
	fmt.Fprintf(&b, "📥 Nieuwe inzending via upload.toorren.net\nVan: %s <%s>\nMap: %s",
		u.fields["naam"], u.fields["email"], strings.Join(u.dir, "/"))
	if len(u.files) > 0 {
		fmt.Fprintf(&b, "\nBestanden (%d, %s):\n- %s", len(u.files), human(u.bytes), strings.Join(u.files, "\n- "))
	}
	if len(u.links) > 0 {
		fmt.Fprintf(&b, "\nLinks (%d):", len(u.links))
		for i, l := range u.links {
			fmt.Fprintf(&b, "\n%d. %s\n   %s", i+1, l.Title, l.URL)
		}
	}
	return b.String()
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
