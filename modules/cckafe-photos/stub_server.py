#!/usr/bin/env python3
"""Nep-Immich voor de test van fetch.sh.

Drie endpoints, genoeg voor de fotodienst:
  GET  /api/albums                  -> de albums van het account
  POST /api/search/metadata         -> de assets van een album
  GET  /api/assets/<id>/thumbnail   -> een JPEG, of de bytes uit preview.bin

Het account is leeg tenzij een testalbum is aangemaakt; de test bestuurt dat
met bestanden in de stub-map:
  album.json   -> het album dat GET /api/albums teruggeeft (of {} voor leeg)
  assets.json  -> het antwoord van POST /api/search/metadata
  calls        -> log van de aanroepen (methode pad sleutel)
  preview.bin  -> optioneel: eigen preview-bytes (bijv. een echte WebP)
  preview.type -> optioneel: het Content-Type daarbij (standaard image/webp)
"""

import json
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

STUB = os.environ.get("STUB", ".")
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 18733

# Een minimale geldige JPEG (1x1 pixel, grijs).
JPEG = bytes.fromhex(
    "ffd8ffe000104a46494600010100000100010000ffdb004300"
    + "08060607060508070707090909080a0c140d0c0b0b0c1912130f141d1a1f1e1d1a1c1c20242e2720222c231c1c2837292c30313434341f27393d38323c2e333432"
    + "ffc0000b080001000101011100ffc40014000100000000000000000000000000000009ffc40014100100000000000000000000000000000000ffda0008010100003f00d2cf20ffd9"
)


def read(name, default):
    path = os.path.join(STUB, name)
    if not os.path.exists(path):
        return default
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def log_call(method, path, key):
    with open(os.path.join(STUB, "calls"), "a", encoding="utf-8") as fh:
        fh.write(f"{method} {path} {key}\n")


class Handler(BaseHTTPRequestHandler):
    server_version = "stub-immich/1.0"

    def _send(self, code, body, content_type="application/json"):
        data = body if isinstance(body, bytes) else body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(data)

    def _key(self):
        return self.headers.get("x-api-key", "")

    def do_GET(self):  # noqa: N802 - stdlib API
        path = self.path.split("?", 1)[0]
        log_call("GET", path, self._key())
        if path == "/api/albums":
            album = read("album.json", "{}")
            self._send(200, album if album.strip() else "[]")
            return
        if path.startswith("/api/assets/") and path.endswith("/thumbnail"):
            if os.path.exists(os.path.join(STUB, "thumb-fail")):
                self._send(500, '{"message":"stub failure"}')
                return
            # Eigen bytes, zodat de test ook een echte WebP-preview kan nabootsen.
            preview = os.path.join(STUB, "preview.bin")
            if os.path.exists(preview):
                with open(preview, "rb") as fh:
                    data = fh.read()
                ctype = read("preview.type", "image/webp").strip() or "image/webp"
                self._send(200, data, ctype)
                return
            self._send(200, JPEG, "image/jpeg")
            return
        self._send(404, '{"message":"not found"}')

    def do_POST(self):  # noqa: N802 - stdlib API
        path = self.path.split("?", 1)[0]
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length).decode("utf-8") if length else ""
        log_call("POST", path, self._key())
        if path == "/api/search/metadata":
            assets = read("assets.json", '{"assets":{"total":0,"items":[]}}')
            self._send(200, assets)
            return
        self._send(404, '{"message":"not found"}')

    def log_message(self, *args):  # stil: de test leest de 'calls'-log
        pass


def main():
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"stub-immich luistert op 127.0.0.1:{PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
