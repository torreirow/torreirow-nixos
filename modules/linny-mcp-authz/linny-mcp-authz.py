#!/usr/bin/env python3
"""Tokenvalidator tussen nginx en linny-mcp.

Nginx' `auth_request` kan alleen op een STATUSCODE beslissen. Authelia's
introspection-endpoint antwoordt echter met 200 en `{"active": false}` voor een
ongeldig token -- de status alleen zegt dus niets en de body moet gelezen worden.
Dat is precies wat deze dienst doet, en de enige reden dat hij bestaat.

    nginx auth_request  ->  deze dienst  ->  POST /api/oidc/introspection
                            200 of 401       {"active": true, ...}

Waarom niet Authelia's eigen authz-endpoint: dat accepteert alleen tokens met de
scope `authelia.bearer.authz`, en Authelia eist bij die scope verplicht PAR.
Claude doet geen PAR -- gemeten, ook niet wanneer de discovery-metadata het als
verplicht adverteert. Zie openspec/changes/add-linny-mcp-oidc/design.md.

Alleen de standaardbibliotheek: deze dienst zit in het pad van elke MCP-aanroep,
en een afhankelijkheid minder is er een minder om te breken.
"""

from __future__ import annotations

import base64
import hashlib
import json
import os
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def env(name: str, default: str | None = None) -> str:
    value = os.environ.get(name, default)
    if value is None:
        sys.exit(f"linny-mcp-authz: {name} ontbreekt")
    return value


INTROSPECTION_URL = env("AUTHZ_INTROSPECTION_URL")
CLIENT_ID = env("AUTHZ_CLIENT_ID")
EXPECTED_CLIENT = env("AUTHZ_EXPECTED_CLIENT")
LISTEN_HOST = env("AUTHZ_LISTEN_HOST", "127.0.0.1")
LISTEN_PORT = int(env("AUTHZ_LISTEN_PORT", "8097"))
# Een MCP-sessie doet véél aanroepen. Zonder cache zou elke tool-call een
# introspection-ronde naar Authelia kosten; met 60s blijft een ingetrokken token
# hooguit een minuut bruikbaar. Dat is de afweging, bewust kort gehouden.
CACHE_TTL = float(env("AUTHZ_CACHE_TTL", "60"))
# Leeg = niet zetten. Nodig wanneer INTROSPECTION_URL naar loopback wijst terwijl
# Authelia op zijn publieke naam geconfigureerd staat.
HOST_HEADER = os.environ.get("AUTHZ_HOST_HEADER", "")

with open(env("AUTHZ_CLIENT_SECRET_FILE"), encoding="utf-8") as fh:
    CLIENT_SECRET = fh.read().strip()


class Cache:
    """TTL-cache op de sha256 van het token -- nooit het token zelf."""

    def __init__(self, ttl: float) -> None:
        self._ttl = ttl
        self._lock = threading.Lock()
        self._entries: dict[str, float] = {}

    def valid(self, digest: str) -> bool:
        now = time.monotonic()
        with self._lock:
            expires = self._entries.get(digest)
            if expires is None:
                return False
            if expires <= now:
                del self._entries[digest]
                return False
            return True

    def remember(self, digest: str) -> None:
        now = time.monotonic()
        with self._lock:
            # Meteen opruimen wat verlopen is; deze dienst draait lang en het
            # aantal sleutels is klein, dus een aparte opruimlus is overbodig.
            for key, expires in list(self._entries.items()):
                if expires <= now:
                    del self._entries[key]
            self._entries[digest] = now + self._ttl


CACHE = Cache(CACHE_TTL)


def parse_bearer(header: str | None) -> str | None:
    """Het token uit een Authorization-header, of None.

    Bewust tolerant op hoofdletters in het schema (RFC 7235 zegt dat het
    case-insensitive is) en streng op de rest: precies twee velden.
    """
    if not header:
        return None
    parts = header.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        return None
    return parts[1] or None


def introspect(token: str) -> dict:
    """RFC 7662. Werpt bij netwerk- of protocolfouten."""
    # client_secret_basic, niet _post. Authelia registreert per client één
    # toegestane methode en die staat standaard op basic; met _post weigert het
    # endpoint met "the OAuth 2.0 client registration does not allow this method".
    body = urllib.parse.urlencode({"token": token}).encode()
    request = urllib.request.Request(INTROSPECTION_URL, data=body, method="POST")
    request.add_header("Content-Type", "application/x-www-form-urlencoded")
    request.add_header("Accept", "application/json")
    basic = base64.b64encode(f"{CLIENT_ID}:{CLIENT_SECRET}".encode()).decode()
    request.add_header("Authorization", f"Basic {basic}")
    # Authelia draait op dezelfde host; we praten over loopback en doen ons voor
    # als de reverse proxy. Anders loopt élke introspection via de publieke
    # DNS-naam de router uit en weer in, en ligt de MCP-server plat zodra de
    # internetverbinding hapert.
    #
    # Beide headers zijn nodig. Authelia leidt de "effective issuer" uit het
    # verzoek af en weigert met `invalid X-Forwarded-Proto header value 'http'`
    # als je alleen de Host meestuurt -- de issuer moet https zijn.
    if HOST_HEADER:
        request.add_header("Host", HOST_HEADER)
        request.add_header("X-Forwarded-Proto", "https")
        request.add_header("X-Forwarded-Host", HOST_HEADER)
    with urllib.request.urlopen(request, timeout=5) as response:
        return json.loads(response.read())


def allowed(claims: dict) -> bool:
    """Deny-by-default: alles moet kloppen, niet één ding.

    `active` alleen is niet genoeg. Zonder de client-check zou élk geldig token
    van élke client op deze Authelia toegang geven -- ook dat van Wallos.
    """
    if claims.get("active") is not True:
        return False
    if claims.get("client_id") != EXPECTED_CLIENT:
        return False
    return True


class Handler(BaseHTTPRequestHandler):
    server_version = "linny-mcp-authz"
    sys_version = ""

    def log_message(self, fmt, *args):  # noqa: A003
        """Standaard logt BaseHTTPRequestHandler het volledige verzoekpad naar
        stderr, en daarmee in het journaal. Hier loopt tokenmateriaal langs, dus
        dat zetten we uit; de dienst logt zelf wat nodig is, zonder waarden."""
        return

    def _answer(self, status: int) -> None:
        self.send_response(status)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/healthz":
            self._answer(200)
            return

        token = parse_bearer(self.headers.get("Authorization"))
        if token is None:
            self._answer(401)
            return

        digest = hashlib.sha256(token.encode()).hexdigest()
        if CACHE.valid(digest):
            self._answer(200)
            return

        try:
            claims = introspect(token)
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError) as exc:
            # Authelia onbereikbaar of stuk: 503, niet 401. Nginx maakt daar een
            # 500 van, en dat is eerlijker dan "ongeldig token" -- anders jaag je
            # bij een storing iedereen zijn sessie opnieuw door de inlog.
            print(f"linny-mcp-authz: introspection mislukt: {type(exc).__name__}", flush=True)
            self._answer(503)
            return

        if allowed(claims):
            CACHE.remember(digest)
            self._answer(200)
        else:
            self._answer(401)

    do_POST = do_GET  # nginx stuurt de subrequest door met de oorspronkelijke methode


def main() -> None:
    server = ThreadingHTTPServer((LISTEN_HOST, LISTEN_PORT), Handler)
    server.daemon_threads = True
    print(f"linny-mcp-authz: luistert op {LISTEN_HOST}:{LISTEN_PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
