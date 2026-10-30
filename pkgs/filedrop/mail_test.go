package main

import (
	"bufio"
	"net"
	"net/http"
	"strings"
	"testing"
)

// fakeSMTP accepts one message and returns its DATA section on the channel.
func fakeSMTP(t *testing.T) (string, <-chan string) {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { ln.Close() })
	got := make(chan string, 1)
	go func() {
		c, err := ln.Accept()
		if err != nil {
			return
		}
		defer c.Close()
		r := bufio.NewReader(c)
		w := func(s string) { c.Write([]byte(s + "\r\n")) }
		w("220 fake")
		var data strings.Builder
		inData := false
		for {
			line, err := r.ReadString('\n')
			if err != nil {
				return
			}
			switch {
			case inData && line == ".\r\n":
				inData = false
				got <- data.String()
				w("250 ok")
			case inData:
				data.WriteString(line)
			case strings.HasPrefix(line, "EHLO"), strings.HasPrefix(line, "HELO"):
				w("250 fake")
			case strings.HasPrefix(line, "DATA"):
				inData = true
				w("354 go")
			case strings.HasPrefix(line, "QUIT"):
				w("221 bye")
				return
			default:
				w("250 ok")
			}
		}
	}()
	return ln.Addr().String(), got
}

func TestMailNotification(t *testing.T) {
	newFakeBackend(t)
	addr, got := fakeSMTP(t)
	smtpAddr, notifyEmail, mailFrom = addr, "eghupload@example.org", "noreply@example.org"
	t.Cleanup(func() { notifyEmail = "" })

	code, msg := submit(t, with(field{"link1", "https://youtu.be/x", ""},
		field{"bericht", "geheim bericht", ""})...)
	if code != http.StatusOK {
		t.Fatalf("status %d: %s", code, msg)
	}
	mail := <-got
	for _, want := range []string{"To: eghupload@example.org", "Reply-To: test@example.org",
		"Subject: Nieuwe inzending van Test Persoon", "Map: ", "https://youtu.be/x"} {
		if !strings.Contains(mail, want) {
			t.Errorf("mail misses %q:\n%s", want, mail)
		}
	}
	if strings.Contains(mail, "geheim bericht") {
		t.Error("the uploader's message leaked into the mail")
	}
}

func TestMailHeaderInjection(t *testing.T) {
	addr, got := fakeSMTP(t)
	smtpAddr, notifyEmail, mailFrom = addr, "eghupload@example.org", "noreply@example.org"
	t.Cleanup(func() { notifyEmail = "" })
	if err := sendMail("Nieuwe inzending van Zoë\r\nBcc: evil@example.org", "tekst", ""); err != nil {
		t.Fatal(err)
	}
	mail := <-got
	if strings.Contains(mail, "\r\nBcc:") {
		t.Errorf("header injection:\n%s", mail)
	}
	if !strings.Contains(mail, "Subject: =?utf-8?q?") {
		t.Errorf("non-ASCII subject not encoded:\n%s", mail)
	}
}
