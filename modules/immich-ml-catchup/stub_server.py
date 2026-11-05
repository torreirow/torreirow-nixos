# Nep-ML + nep-Immich-jobs-API voor test.nix. Gedrag via bestanden in de stub-map:
# ml-down -> /ping faalt; already-running -> PUT geeft 400 "Job is already running".
# Elke geaccepteerde PUT komt als "<queue> <api-key> <force>" in calls.
import json, os, sys
from http.server import BaseHTTPRequestHandler, HTTPServer

port, d = int(sys.argv[1]), sys.argv[2]

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def send(self, code, body):
        b = body.encode()
        self.send_response(code)
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        if self.path == "/health":
            return self.send(200, "ok")
        if self.path == "/ping" and not os.path.exists(f"{d}/ml-down"):
            return self.send(200, "pong")
        self.send(503, "down")

    def do_PUT(self):
        key = self.headers.get("x-api-key", "")
        data = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        if key != "testkey":
            return self.send(401, '{"message":"Invalid API key"}')
        if not self.path.startswith("/api/jobs/") or data.get("command") != "start":
            return self.send(404, "nee")
        q = self.path.rsplit("/", 1)[1]
        with open(f"{d}/calls", "a") as f:
            f.write(f"{q} {key} {str(data.get('force')).lower()}\n")
        if os.path.exists(f"{d}/already-running"):
            return self.send(400, '{"message":"Job is already running"}')
        self.send(200, "{}")

HTTPServer(("127.0.0.1", port), H).serve_forever()
