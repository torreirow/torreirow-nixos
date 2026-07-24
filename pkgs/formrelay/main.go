package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"net/smtp"
	"net/url"
	"os"
	"sort"
	"strings"
	"time"
)

type FormConfig struct {
	Name           string   `json:"name"`
	To             string   `json:"to"`
	AllowedOrigins []string `json:"allowedOrigins"`
}

type Config struct {
	Port        int                   `json:"port"`
	FromAddress string                `json:"fromAddress"`
	Forms       map[string]FormConfig `json:"forms"`
}

var (
	cfg            Config
	hcaptchaSecret string
)

func main() {
	configPath := flag.String("config", "", "path to config JSON file")
	secretPath := flag.String("hcaptcha-secret-file", "", "path to hCaptcha secret key file")
	flag.Parse()

	if *configPath == "" || *secretPath == "" {
		log.Fatal("--config and --hcaptcha-secret-file are required")
	}

	data, err := os.ReadFile(*configPath)
	if err != nil {
		log.Fatalf("read config: %v", err)
	}
	if err := json.Unmarshal(data, &cfg); err != nil {
		log.Fatalf("parse config: %v", err)
	}

	for token, form := range cfg.Forms {
		if form.To == "" {
			log.Fatalf("form token %q: missing 'to' field", token)
		}
	}

	secretBytes, err := os.ReadFile(*secretPath)
	if err != nil {
		log.Fatalf("read hcaptcha secret: %v", err)
	}
	hcaptchaSecret = strings.TrimSpace(string(secretBytes))

	addr := fmt.Sprintf("127.0.0.1:%d", cfg.Port)
	log.Printf("formrelay listening on %s with %d form(s)", addr, len(cfg.Forms))

	mux := http.NewServeMux()
	mux.HandleFunc("/submit", handleSubmit)
	log.Fatal(http.ListenAndServe(addr, mux))
}

func writeJSON(w http.ResponseWriter, status int, body string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	fmt.Fprint(w, body)
}

func setCORSHeaders(w http.ResponseWriter, origin string, form FormConfig) bool {
	for _, allowed := range form.AllowedOrigins {
		if allowed == origin {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
			return true
		}
	}
	return false
}

func handleSubmit(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodOptions {
		if err := r.ParseForm(); err == nil {
			if form, ok := cfg.Forms[r.FormValue("_token")]; ok {
				setCORSHeaders(w, r.Header.Get("Origin"), form)
			}
		}
		w.WriteHeader(http.StatusNoContent)
		return
	}

	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, `{"ok":false,"error":"method not allowed"}`)
		return
	}

	if err := r.ParseMultipartForm(1 << 20); err != nil {
		if err := r.ParseForm(); err != nil {
			writeJSON(w, http.StatusBadRequest, `{"ok":false,"error":"invalid request body"}`)
			return
		}
	}

	origin := r.Header.Get("Origin")

	token := r.FormValue("_token")
	if token == "" {
		writeJSON(w, http.StatusBadRequest, `{"ok":false,"error":"missing token"}`)
		return
	}

	form, ok := cfg.Forms[token]
	if !ok {
		writeJSON(w, http.StatusForbidden, `{"ok":false,"error":"invalid token"}`)
		return
	}

	if !setCORSHeaders(w, origin, form) {
		writeJSON(w, http.StatusForbidden, `{"ok":false,"error":"origin not allowed"}`)
		return
	}

	// Honeypot: silently accept without processing
	if r.FormValue("_gotcha") != "" {
		writeJSON(w, http.StatusOK, `{"ok":true}`)
		return
	}

	if !verifyHcaptcha(r.FormValue("h-captcha-response")) {
		writeJSON(w, http.StatusForbidden, `{"ok":false,"error":"captcha verification failed"}`)
		return
	}

	body := buildEmailBody(r)
	senderName := r.FormValue("name")
	subject := fmt.Sprintf("[Formulier: %s] Nieuw bericht", form.Name)
	if senderName != "" {
		subject = fmt.Sprintf("[Formulier: %s] Nieuw bericht van %s", form.Name, senderName)
	}

	if err := sendMail(cfg.FromAddress, form.To, subject, body); err != nil {
		log.Printf("sendmail error: %v", err)
		writeJSON(w, http.StatusInternalServerError, `{"ok":false,"error":"internal error"}`)
		return
	}

	writeJSON(w, http.StatusOK, `{"ok":true}`)
}

var skipFields = map[string]bool{
	"_token": true, "_honeypot": true, "_gotcha": true, "h-captcha-response": true,
}

func buildEmailBody(r *http.Request) string {
	keys := make([]string, 0, len(r.Form))
	for k := range r.Form {
		if !skipFields[k] {
			keys = append(keys, k)
		}
	}
	sort.Strings(keys)

	var lines []string
	for _, k := range keys {
		lines = append(lines, fmt.Sprintf("%s: %s", k, strings.Join(r.Form[k], ", ")))
	}
	return strings.Join(lines, "\n")
}

func verifyHcaptcha(response string) bool {
	if response == "" {
		return false
	}
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.PostForm("https://api.hcaptcha.com/siteverify", url.Values{
		"secret":   {hcaptchaSecret},
		"response": {response},
	})
	if err != nil {
		log.Printf("hcaptcha API error: %v", err)
		return false
	}
	defer resp.Body.Close()

	var result struct {
		Success bool `json:"success"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		log.Printf("hcaptcha decode error: %v", err)
		return false
	}
	return result.Success
}

func sendMail(from, to, subject, body string) error {
	msg := fmt.Sprintf(
		"From: %s\r\nTo: %s\r\nSubject: %s\r\nContent-Type: text/plain; charset=utf-8\r\n\r\n%s",
		from, to, subject, body,
	)
	return smtp.SendMail("127.0.0.1:25", nil, from, []string{to}, []byte(msg))
}
