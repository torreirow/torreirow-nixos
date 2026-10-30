#!/usr/bin/env python3
# Local stand-ins for dev.sh: Cap siteverify (always succeeds), the Nextcloud
# WebDAV share (writes into the directory given as first argument) and the
# Signal API (prints messages). Listens on 127.0.0.1:18110.
import http.server
import json
import os
import sys
import urllib.parse

SHARE = os.path.abspath(sys.argv[1])


class Stub(http.server.BaseHTTPRequestHandler):
    def target(self):
        # /public.php/dav/files/<token>/<path>
        rel = urllib.parse.unquote(self.path.split("/dav/files/", 1)[1].split("/", 1)[1])
        path = os.path.abspath(os.path.join(SHARE, rel))
        if not path.startswith(SHARE + os.sep):
            raise ValueError("path outside share")
        return path

    def reply(self, code, body=b""):
        self.send_response(code)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        if self.path.endswith("/siteverify"):
            self.reply(200, b'{"success": true}')
        elif self.path == "/signal":
            print("\n--- Signal ---\n" + json.loads(body)["message"] + "\n--------------", flush=True)
            self.reply(201)
        else:
            self.reply(404)

    def do_MKCOL(self):
        path = self.target()
        if os.path.isdir(path):
            self.reply(405)
            return
        os.makedirs(path)
        self.reply(201)

    def do_PUT(self):
        path = self.target()
        with open(path, "wb") as f:
            if self.headers.get("Transfer-Encoding") == "chunked":
                while True:
                    n = int(self.rfile.readline().strip() or b"0", 16)
                    f.write(self.rfile.read(n))
                    self.rfile.readline()
                    if n == 0:
                        break
            else:
                f.write(self.rfile.read(int(self.headers.get("Content-Length", 0))))
        print(f"opgeslagen: {os.path.relpath(path, SHARE)}", flush=True)
        self.reply(201)

    def log_message(self, *args):
        pass


os.makedirs(SHARE, exist_ok=True)
http.server.ThreadingHTTPServer(("127.0.0.1", 18110), Stub).serve_forever()
