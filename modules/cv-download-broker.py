#!/usr/bin/env python3
"""CV-downloadbroker: verifieert een Cap-token en levert daarna de PDF.

Flow: de browser lost onopvallend een Cap-challenge op en POST /download met
{"token": "...", "lang": "nl"|"en"}. Deze service controleert het token bij
capd (/siteverify), en stuurt bij succes de PDF uit /var/www/cv-wouter/uploads.
Zonder geldig token: 403. De PDF's zijn via nginx niet rechtstreeks bereikbaar.
"""

import json
import os
import sys
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

SITE_KEY = "a9194a3d45"
CAP_VERIFY_URL = f"https://cap.toorren.net/{SITE_KEY}/siteverify"
SECRET_FILE = Path("/run/secrets/cap-cv-secret")
PDF_DIR = Path("/var/www/cv-wouter/uploads")
PDFS = {
    "nl": "cv-wouter-van-der-toorren-nl.pdf",
    "en": "cv-wouter-van-der-toorren-en.pdf",
}
PORT = int(os.environ.get("CV_DOWNLOAD_PORT", "8787"))
MAX_BODY = 8192


def read_secret() -> str:
    return SECRET_FILE.read_text(encoding="utf-8").strip()


def verify_token(token: str, client_ip: str | None) -> bool:
    if not token or len(token) > 4096:
        return False
    payload = json.dumps({"secret": read_secret(), "response": token}).encode()
    headers = {"Content-Type": "application/json"}
    # capd rate-limit per client-IP; geef de echte bezoeker door.
    if client_ip:
        headers["X-Forwarded-For"] = client_ip
    req = urllib.request.Request(CAP_VERIFY_URL, data=payload, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=6) as resp:
            body = json.loads(resp.read(64 * 1024))
            return body.get("success") is True
    except (urllib.error.URLError, urllib.error.HTTPError, ValueError, TimeoutError) as exc:
        print(f"siteverify failed: {exc}", file=sys.stderr, flush=True)
        return False


class Handler(BaseHTTPRequestHandler):
    server_version = "cv-download/1.0"

    def log_message(self, fmt, *args):  # rustiger loggen
        print("%s - %s" % (self.address_string(), fmt % args), file=sys.stderr, flush=True)

    def _json(self, status: int, obj: dict) -> None:
        data = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:
        path = self.path.split("?", 1)[0]
        if path == "/health":
            self._json(200, {"ok": True})
        elif path == "/download":
            # Fallback voor bezoekers zonder JavaScript: geen PDF, alleen uitleg.
            html = (
                "<!doctype html><html lang=nl><meta charset=utf-8>"
                "<title>Download vereist JavaScript</title>"
                "<p>Deze download is beveiligd met een browsercontrole. "
                "Schakel JavaScript in en probeer het opnieuw.</p>"
            ).encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(html)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(html)
        else:
            self._json(405, {"success": False, "error": "method not allowed"})

    def do_POST(self) -> None:
        if self.path != "/download":
            self._json(404, {"success": False, "error": "not found"})
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self._json(400, {"success": False, "error": "bad request"})
            return
        if length <= 0 or length > MAX_BODY:
            self._json(413, {"success": False, "error": "bad request"})
            return

        try:
            body = json.loads(self.rfile.read(length))
            token = str(body.get("token", ""))
            lang = str(body.get("lang", "nl"))
        except (ValueError, AttributeError):
            self._json(400, {"success": False, "error": "bad request"})
            return

        if lang not in PDFS:
            self._json(400, {"success": False, "error": "unknown language"})
            return

        client_ip = self.headers.get("X-Real-IP")
        if not verify_token(token, client_ip):
            self._json(403, {"success": False, "error": "captcha required"})
            return

        path = PDF_DIR / PDFS[lang]
        try:
            data = path.read_bytes()
        except OSError:
            self._json(404, {"success": False, "error": "file not found"})
            return

        self.send_response(200)
        self.send_header("Content-Type", "application/pdf")
        self.send_header("Content-Disposition", f'attachment; filename="{PDFS[lang]}"')
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
