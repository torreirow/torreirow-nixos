package main

import (
	"fmt"
	"log"
	"mime"
	"net/smtp"
	"strings"
	"time"
)

// Mail notification next to Signal, to a fixed internal address (never to the
// uploader). Empty notifyEmail disables it.
var (
	notifyEmail string
	mailFrom    string
	smtpAddr    = "127.0.0.1:25" // local postfix, relays via SES
)

// announce sends a notification via Signal and, when configured, e-mail.
// replyTo is the uploader's (validated) address, or "" for system messages.
func announce(subject, text, replyTo string) {
	notify(text)
	if notifyEmail == "" {
		return
	}
	if err := sendMail(subject, text, replyTo); err != nil {
		log.Printf("mail error: %v", err)
	}
}

func sendMail(subject, text, replyTo string) error {
	headers := []string{
		"From: EGH Media upload <" + mailFrom + ">",
		"To: " + notifyEmail,
		"Subject: " + mime.QEncoding.Encode("utf-8", oneLine(subject)),
		"Date: " + time.Now().Format(time.RFC1123Z),
		"MIME-Version: 1.0",
		"Content-Type: text/plain; charset=utf-8",
		"Content-Transfer-Encoding: 8bit",
	}
	if replyTo != "" {
		headers = append(headers, "Reply-To: "+oneLine(replyTo))
	}
	body := strings.ReplaceAll(strings.ReplaceAll(text, "\r\n", "\n"), "\n", "\r\n")
	msg := strings.Join(headers, "\r\n") + "\r\n\r\n" + body + "\r\n"
	if err := smtp.SendMail(smtpAddr, nil, mailFrom, []string{notifyEmail}, []byte(msg)); err != nil {
		return fmt.Errorf("send to %s: %w", notifyEmail, err)
	}
	return nil
}
