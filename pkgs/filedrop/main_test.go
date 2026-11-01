package main

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"io/fs"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"testing"
	"time"
)

// fakeBackend stands in for Cap, the Nextcloud WebDAV share and the Signal API.
type fakeBackend struct {
	mu       sync.Mutex
	dirs     map[string]bool   // existing folders (MKCOL answers 405)
	files    map[string]string // PUT path -> body
	messages []string          // Signal messages
	failing  map[string]int    // method -> status the share answers with instead
}

func newFakeBackend(t *testing.T) *httptest.Server {
	t.Helper()
	fb := &fakeBackend{dirs: map[string]bool{}, files: map[string]string{}, failing: map[string]int{}}
	backend = fb
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fb.mu.Lock()
		defer fb.mu.Unlock()
		p, _ := url.PathUnescape(strings.TrimPrefix(r.URL.EscapedPath(), "/dav/"))
		switch {
		case strings.HasSuffix(r.URL.Path, "/siteverify"):
			var d map[string]string
			json.NewDecoder(r.Body).Decode(&d)
			json.NewEncoder(w).Encode(map[string]bool{"success": d["response"] == "goed"})
		case r.URL.Path == "/signal":
			var d map[string]any
			json.NewDecoder(r.Body).Decode(&d)
			fb.messages = append(fb.messages, d["message"].(string))
			w.WriteHeader(http.StatusCreated)
		case fb.failing[r.Method] != 0:
			w.WriteHeader(fb.failing[r.Method])
		case r.Method == "MKCOL":
			if fb.dirs[p] {
				w.WriteHeader(http.StatusMethodNotAllowed)
				return
			}
			fb.dirs[p] = true
			w.WriteHeader(http.StatusCreated)
		case r.Method == http.MethodPut:
			b, _ := io.ReadAll(r.Body)
			fb.files[p] = string(b)
			w.WriteHeader(http.StatusCreated)
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	t.Cleanup(srv.Close)

	capURL = srv.URL + "/cap"
	davBase = srv.URL + "/dav"
	signalAPI = srv.URL + "/signal"
	maxBytes = 1 << 20
	contact = "contact@example.org"
	amsterdam, _ = time.LoadLocation("Europe/Amsterdam")
	limits = limitConfig{perIPHour: 100, perIPDay: 100, totalDay: 100, bytesDay: 1 << 30,
		stateFile: t.TempDir() + "/ratelimit.json"}
	oembedEndpoints = map[string]string{}
	return srv
}

var backend *fakeBackend

type field struct{ name, value, filename string }

func submit(t *testing.T, fields ...field) (int, string) {
	t.Helper()
	var buf bytes.Buffer
	mw := multipart.NewWriter(&buf)
	for _, f := range fields {
		if f.filename != "" {
			w, _ := mw.CreateFormFile(f.name, f.filename)
			w.Write([]byte(f.value))
		} else {
			mw.WriteField(f.name, f.value)
		}
	}
	mw.Close()
	req := httptest.NewRequest(http.MethodPost, "/upload", &buf)
	req.Header.Set("Content-Type", mw.FormDataContentType())
	req.Header.Set("X-Real-IP", "192.0.2.1")
	rec := httptest.NewRecorder()
	handleUpload(rec, req)
	var res struct{ Message string }
	json.Unmarshal(rec.Body.Bytes(), &res)
	return rec.Code, res.Message
}

var person = []field{{"naam", "Test Persoon", ""}, {"email", "test@example.org", ""}, {"cap-token", "goed", ""}}

func with(extra ...field) []field { return append(append([]field{}, person...), extra...) }

func filesIn(dir string) map[string]string {
	out := map[string]string{}
	for p, body := range backend.files {
		if strings.HasPrefix(p, dir+"/") {
			out[strings.TrimPrefix(p, dir+"/")] = body
		}
	}
	return out
}

func TestFolderPerMonthAndSubmission(t *testing.T) {
	newFakeBackend(t)
	when := time.Now().In(amsterdam)
	month, sub := when.Format("2006-01"), when.Format("20060102-150405")
	backend.dirs[month] = true         // month folder already exists: 405 is fine
	backend.dirs[month+"/"+sub] = true // same second already taken
	backend.dirs[month+"/"+sub+"-2"] = false

	code, msg := submit(t, with(field{"files", "hallo", "a.txt"})...)
	if code != http.StatusOK {
		t.Fatalf("status %d: %s", code, msg)
	}
	got := filesIn(month + "/" + sub + "-2")
	if got["a.txt"] != "hallo" {
		t.Fatalf("file not stored in %s/%s-2: %v", month, sub, backend.files)
	}
	for p := range backend.files {
		if strings.Contains(p, "Test") || strings.Contains(p, "example.org") {
			t.Errorf("name or e-mail in path %q", p)
		}
	}
}

func TestUniqueNames(t *testing.T) {
	newFakeBackend(t)
	code, msg := submit(t, with(
		field{"files", "1", "foto.jpg"},
		field{"files", "2", "foto.jpg"},
		field{"files", "3", "FOTO.jpg"},
		field{"files", "4", "_afzender.txt"},
	)...)
	if code != http.StatusOK {
		t.Fatalf("status %d: %s", code, msg)
	}
	var dir string
	for p := range backend.files {
		dir = p[:strings.LastIndex(p, "/")]
	}
	got := filesIn(dir)
	want := map[string]string{"foto.jpg": "1", "foto (2).jpg": "2", "FOTO (3).jpg": "3", "_afzender (2).txt": "4"}
	for name, body := range want {
		if got[name] != body {
			t.Errorf("%s = %q, want %q (all: %v)", name, got[name], body, got)
		}
	}
}

func TestSenderFile(t *testing.T) {
	newFakeBackend(t)
	submit(t, with(field{"files", "hallo", "a.txt"})...)
	var sender string
	for p, body := range backend.files {
		if strings.HasSuffix(p, "/_afzender.txt") {
			sender = body
		}
	}
	for _, want := range []string{"Naam: Test Persoon\r\n", "E-mail: test@example.org\r\n", "Tijdstip: ",
		"Bestanden (1, 0 kB):\r\n- a.txt\r\n", "Links: 0"} {
		if !strings.Contains(sender, want) {
			t.Errorf("_afzender.txt misses %q:\n%s", want, sender)
		}
	}
}

func TestParseLinks(t *testing.T) {
	cases := []struct {
		url string
		ok  bool
	}{
		{"https://www.facebook.com/reel/1020909047431110", true},
		{"https://www.instagram.com/reels/DfG9eQtuo5k", true},
		{"https://vimeo.com/1132937?fl=pl&fe=cm", true},
		{"https://www.youtube.com/shorts/spyb-6zbp0A", true},
		{"https://www.youtube.com/watch?v=MTn_bhTVr2U", true},
		{"https://m.youtube.com/watch?v=x", true},
		{"https://youtu.be/abc", true},
		{"https://fb.watch/abc/", true},
		{"http://www.youtube.com/watch?v=x", false},
		{"https://evilyoutube.com/watch?v=x", false},
		{"https://youtube.com.evil.nl/watch?v=x", false},
		{"https://example.org/", false},
		{"javascript:alert(1)", false},
	}
	for _, c := range cases {
		_, err := parseLinks(map[string]string{"link1": c.url})
		if (err == nil) != c.ok {
			t.Errorf("%s: ok=%v, err=%v", c.url, c.ok, err)
		}
	}
	six := map[string]string{}
	for _, k := range []string{"link1", "link2", "link3", "link4", "link5", "link6"} {
		six[k] = "https://youtu.be/x"
	}
	if _, err := parseLinks(six); err == nil {
		t.Error("6 links accepted")
	}
	if _, err := parseLinks(map[string]string{"link1": "https://youtu.be/x", "titel1": strings.Repeat("a", 201)}); err == nil {
		t.Error("201-character title accepted")
	}
	links, _ := parseLinks(map[string]string{"link3": "https://youtu.be/c", "link1": "https://youtu.be/a", "link2": ""})
	if len(links) != 2 || links[0].URL != "https://youtu.be/a" {
		t.Errorf("order/empty skipping wrong: %+v", links)
	}
}

func TestLinksOnlyAndEmpty(t *testing.T) {
	newFakeBackend(t)
	code, msg := submit(t, with(field{"link1", "https://www.instagram.com/reels/DfG9eQtuo5k", ""})...)
	if code != http.StatusOK {
		t.Fatalf("links only: status %d: %s", code, msg)
	}
	code, msg = submit(t, person...)
	if code != http.StatusBadRequest || msg != "Kies minstens één bestand of vul een link in." {
		t.Fatalf("empty: status %d: %s", code, msg)
	}
	code, msg = submit(t, with(field{"link1", "https://example.org/", ""})...)
	if code != http.StatusBadRequest || msg != "Link 1 kunnen we niet gebruiken. Alleen links van YouTube, Facebook, Instagram en Vimeo werken." {
		t.Fatalf("bad host: status %d: %s", code, msg)
	}
}

func TestTitles(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case strings.Contains(r.URL.RawQuery, "slow"):
			time.Sleep(300 * time.Millisecond)
		case strings.Contains(r.URL.RawQuery, "leeg"):
			w.Write([]byte(`{}`))
		default:
			w.Write([]byte(`{"title":"Ren - Vincent's Tale\n- Starry Night","author_name":"Ren"}`))
		}
	}))
	defer srv.Close()
	oembedEndpoints = map[string]string{"YouTube-video": srv.URL + "/?url=", "Vimeo-video": srv.URL + "/?url="}
	oembedClient = &http.Client{Timeout: 100 * time.Millisecond}

	links := []link{
		{URL: "https://youtu.be/ok", platform: "YouTube-video"},
		{URL: "https://youtu.be/slow", platform: "YouTube-video"},
		{URL: "https://vimeo.com/leeg", platform: "Vimeo-video"},
		{URL: "https://www.instagram.com/reels/x", platform: "Instagram-reel"},
		{URL: "https://youtu.be/eigen", Title: "Voor zondag, vanaf 2:15", platform: "YouTube-video"},
	}
	fetchTitles(context.Background(), links)
	want := []string{"Ren - Vincent's Tale - Starry Night (Ren)", "YouTube-video", "Vimeo-video",
		"Instagram-reel", "Voor zondag, vanaf 2:15"}
	for i, w := range want {
		if links[i].Title != w {
			t.Errorf("link %d: title %q, want %q", i, links[i].Title, w)
		}
	}
}

// The expected bytes match the example in docs/filedrop.md.
func TestRenderLinks(t *testing.T) {
	got := string(renderLinks([]link{
		{URL: "https://vimeo.com/1132937?fl=pl&fe=cm", Title: "Elephants Dream (Blender)"},
		{URL: "https://www.instagram.com/reels/DfG9eQtuo5k", Title: "Instagram-reel"},
	}))
	want := "1\r\nElephants Dream (Blender)\r\nhttps://vimeo.com/1132937?fl=pl&fe=cm\r\n" +
		"\r\n" +
		"2\r\nInstagram-reel\r\nhttps://www.instagram.com/reels/DfG9eQtuo5k\r\n"
	if got != want {
		t.Errorf("got %q\nwant %q", got, want)
	}
}

func TestLinksFileAndSignal(t *testing.T) {
	newFakeBackend(t)
	code, msg := submit(t, with(
		field{"link1", "https://vimeo.com/1132937?fl=pl&fe=cm", ""},
		field{"titel1", "Elephants Dream (Blender)", ""},
		field{"link2", "https://www.instagram.com/reels/DfG9eQtuo5k", ""},
	)...)
	if code != http.StatusOK || msg != "Bedankt! We hebben 2 links ontvangen. Het Scherm Team bekijkt je inzending. Je kunt dit venster sluiten." {
		t.Fatalf("status %d: %s", code, msg)
	}
	var linksTxt, dir string
	for p, body := range backend.files {
		if strings.HasSuffix(p, "/video-links.txt") {
			linksTxt, dir = body, strings.TrimSuffix(p, "/video-links.txt")
		}
	}
	if !strings.HasPrefix(linksTxt, "1\r\nElephants Dream (Blender)\r\nhttps://vimeo.com/1132937?fl=pl&fe=cm\r\n") ||
		!strings.Contains(linksTxt, "2\r\nInstagram-reel\r\n") {
		t.Errorf("video-links.txt:\n%q", linksTxt)
	}
	if len(backend.messages) != 1 {
		t.Fatalf("signal messages: %v", backend.messages)
	}
	m := backend.messages[0]
	for _, want := range []string{"Map: " + dir, "https://vimeo.com/1132937?fl=pl&fe=cm", "Instagram-reel", "Test Persoon"} {
		if !strings.Contains(m, want) {
			t.Errorf("signal message misses %q:\n%s", want, m)
		}
	}
}

func TestHoneypotLinksOnly(t *testing.T) {
	newFakeBackend(t)
	code, _ := submit(t, with(field{"website", "x", ""}, field{"link1", "https://youtu.be/x", ""})...)
	if code != http.StatusOK || len(backend.files) != 0 || len(backend.messages) != 0 {
		t.Fatalf("honeypot stored something: %d %v %v", code, backend.files, backend.messages)
	}
}

// Calls the real oEmbed endpoints; run with FILEDROP_LIVE=1 go test -run TestLiveOembed -v
func TestLiveOembed(t *testing.T) {
	if os.Getenv("FILEDROP_LIVE") == "" {
		t.Skip("set FILEDROP_LIVE=1 to call the real oEmbed endpoints")
	}
	links := []link{
		{URL: "https://www.youtube.com/watch?v=MTn_bhTVr2U", platform: "YouTube-video"},
		{URL: "https://www.youtube.com/shorts/spyb-6zbp0A", platform: "YouTube-video"},
		{URL: "https://vimeo.com/1132937?fl=pl&fe=cm", platform: "Vimeo-video"},
		{URL: "https://www.facebook.com/reel/1020909047431110", platform: "Facebook-video"},
	}
	fetchTitles(context.Background(), links)
	for _, l := range links {
		t.Logf("%s -> %s", l.URL, l.Title)
	}
	if links[0].Title != "Ren - Vincent's Tale - Starry Night (Ren)" || links[2].Title != "Elephants Dream (Blender)" {
		t.Errorf("unexpected titles: %+v", links)
	}
}

func TestLinkAfterFileRejected(t *testing.T) {
	newFakeBackend(t)
	code, msg := submit(t, with(field{"files", "x", "a.txt"}, field{"link1", "https://youtu.be/x", ""})...)
	if code != http.StatusBadRequest || !strings.Contains(msg, "vóór de bestanden") {
		t.Fatalf("status %d: %s", code, msg)
	}
}

func TestReceivedMessage(t *testing.T) {
	newFakeBackend(t)
	_, msg := submit(t, with(field{"link1", "https://youtu.be/x", ""}, field{"files", "a", "a.txt"},
		field{"files", "b", "b.txt"})...)
	if msg != "Bedankt! We hebben 2 bestanden en 1 link ontvangen. Het Scherm Team bekijkt je inzending. Je kunt dit venster sluiten." {
		t.Errorf("message %q", msg)
	}
}

// The page is for non-technical people: fixed section order, robot check right
// above the button, and a closed help block.
func TestPageLayout(t *testing.T) {
	markers := []string{
		`<details class="help">`, "Handleiding: hoe werkt het insturen?",
		"Jouw gegevens", "alleen voor deze inzending", "Bestanden</h2>", "Bestanden kiezen",
		`class="andor">en/of`, "Videolinks</h2>", "Bericht", `name="bericht"`, "Versturen</h2>", "<cap-widget", `id="submit"`, `<dialog id="msg"`,
	}
	pos := -1
	for _, m := range markers {
		i := strings.Index(indexHTML, m)
		if i < 0 {
			t.Fatalf("page misses %q", m)
		}
		if i < pos {
			t.Errorf("%q is out of order", m)
		}
		pos = i
	}
	if strings.Contains(indexHTML, "<details class=\"help\" open") {
		t.Error("help block must start closed")
	}
	for _, word := range []string{"captcha", "upload", "URL"} {
		// The "Media upload" subtitle is requested; nothing else may use these words.
		text := visibleText(regexp.MustCompile(`(?s)<p class="subtitle">.*?</p>|<title>.*?</title>`).ReplaceAllString(indexHTML, ""))
		if strings.Contains(strings.ToLower(text), strings.ToLower(word)) {
			t.Errorf("technical word %q visible on the page", word)
		}
	}
}

// visibleText drops tags, attributes, comments and scripts, leaving what a visitor reads.
func visibleText(page string) string {
	page = regexp.MustCompile(`(?s)<script.*?</script>|<style.*?</style>|<!--.*?-->|<[^>]*>`).ReplaceAllString(page, " ")
	return page
}

func TestMessageFile(t *testing.T) {
	newFakeBackend(t)
	code, msg := submit(t, with(field{"link1", "https://youtu.be/x", ""},
		field{"bericht", "Graag zondag\ntijdens de mededelingen", ""})...)
	if code != http.StatusOK {
		t.Fatalf("status %d: %s", code, msg)
	}
	var stored string
	for p, body := range backend.files {
		if strings.HasSuffix(p, "/bericht.txt") {
			stored = body
		}
	}
	if stored != "Graag zondag\r\ntijdens de mededelingen\r\n" {
		t.Errorf("bericht.txt = %q", stored)
	}
	if strings.Contains(backend.messages[0], "zondag") {
		t.Errorf("message leaked into Signal: %s", backend.messages[0])
	}

	newFakeBackend(t)
	submit(t, with(field{"link1", "https://youtu.be/x", ""}, field{"bericht", "  ", ""})...)
	for p := range backend.files {
		if strings.HasSuffix(p, "/bericht.txt") {
			t.Error("bericht.txt created for an empty message")
		}
	}

	code, msg = submit(t, with(field{"link1", "https://youtu.be/x", ""}, field{"bericht", strings.Repeat("é", 1001), ""})...)
	if code != http.StatusBadRequest || !strings.Contains(msg, "te lang") {
		t.Errorf("1001 characters: status %d: %s", code, msg)
	}
	code, _ = submit(t, with(field{"link1", "https://youtu.be/x", ""}, field{"bericht", strings.Repeat("é", 1000), ""})...)
	if code != http.StatusOK {
		t.Errorf("1000 characters rejected: %d", code)
	}

	code, msg = submit(t, with(field{"bericht", "alleen tekst", ""})...)
	if code != http.StatusBadRequest || msg != "Kies minstens één bestand of vul een link in." {
		t.Errorf("message only: status %d: %s", code, msg)
	}
}

// get requests path from the real routes.
func get(t *testing.T, path string) *httptest.ResponseRecorder {
	t.Helper()
	rec := httptest.NewRecorder()
	routes().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
	return rec
}

func TestStaticAssets(t *testing.T) {
	for path, contentType := range map[string]string{
		"/logo.png":                   "image/png",
		"/hero.webp":                  "image/webp",
		"/fonts/blenda-script.woff2":  "font/woff2",
		"/fonts/roboto-regular.woff2": "font/woff2",
		"/fonts/roboto-bold.woff2":    "font/woff2",
		"/fonts/roboto-italic.woff2":  "font/woff2",
	} {
		rec := get(t, path)
		if rec.Code != http.StatusOK || rec.Header().Get("Content-Type") != contentType || rec.Body.Len() == 0 {
			t.Errorf("%s: status %d, type %q, %d bytes", path, rec.Code, rec.Header().Get("Content-Type"), rec.Body.Len())
		}
	}
}

func TestLetterGothicOptional(t *testing.T) {
	fontDir = t.TempDir()
	if rec := get(t, "/fonts/letter-gothic.woff2"); rec.Code != http.StatusNotFound {
		t.Fatalf("without the font: status %d, want 404", rec.Code)
	}
	if err := os.WriteFile(fontDir+"/LetterGothicStd.woff2", []byte("wOF2"), 0o644); err != nil {
		t.Fatal(err)
	}
	rec := get(t, "/fonts/letter-gothic.woff2")
	if rec.Code != http.StatusOK || rec.Header().Get("Content-Type") != "font/woff2" || rec.Body.String() != "wOF2" {
		t.Errorf("after placing the font: status %d, type %q", rec.Code, rec.Header().Get("Content-Type"))
	}
}

// The Adobe Letter Gothic font is licensed for this site, not for redistribution: it lives on the
// server only (FONT_DIR), never in this public repository.
func TestNoLicensedFontInRepo(t *testing.T) {
	filepath.WalkDir(".", func(p string, d fs.DirEntry, err error) error {
		if d.IsDir() && (p == "dev-fonts" || p == "dev-share") {
			return filepath.SkipDir
		}
		if strings.Contains(strings.ToLower(d.Name()), "lettergothic") {
			t.Errorf("%s must not be in the repository", p)
		}
		return nil
	})
}

// Fonts, images and styles come from this service; only the robot check (Cap) is external.
func TestNoExternalAssets(t *testing.T) {
	refs := regexp.MustCompile(`(?:src|href)="([^"]*)"|url\(\s*['"]?([^'")]*)`).FindAllStringSubmatch(indexHTML, -1)
	if len(refs) == 0 {
		t.Fatal("no references found")
	}
	for _, m := range refs {
		ref := m[1] + m[2]
		switch {
		case strings.HasPrefix(ref, "/") && !strings.HasPrefix(ref, "//"),
			strings.HasPrefix(ref, "mailto:"),
			ref == "{{CAP_ENDPOINT}}",
			strings.HasPrefix(ref, "https://cdn.jsdelivr.net/npm/@cap.js/widget@"):
		default:
			t.Errorf("external or unexpected reference %q", ref)
		}
	}
}

func TestStorageErrors(t *testing.T) {
	for _, c := range []struct {
		method, want string
		status, code int
	}{
		{"MKCOL", "23:00", http.StatusServiceUnavailable, http.StatusServiceUnavailable}, // night: proxy answers 503
		{"PUT", "23:00", http.StatusBadGateway, http.StatusServiceUnavailable},           // gone during the upload
		{"PUT", "iets mis", http.StatusInternalServerError, http.StatusBadGateway},       // any other failure
	} {
		newFakeBackend(t)
		backend.failing[c.method] = c.status
		code, msg := submit(t, with(field{"files", "x", "foto.jpg"})...)
		if code != c.code || !strings.Contains(msg, c.want) || !strings.HasSuffix(msg, "contact op via contact@example.org.") {
			t.Errorf("%s answering %d: status %d: %s", c.method, c.status, code, msg)
		}
	}

	newFakeBackend(t)
	davBase = "http://127.0.0.1:1/dav" // connection refused, while the robot check still works
	if code, msg := submit(t, with(field{"files", "x", "foto.jpg"})...); code != http.StatusServiceUnavailable || !strings.Contains(msg, "09:00") {
		t.Errorf("unreachable: status %d: %s", code, msg)
	}
}
