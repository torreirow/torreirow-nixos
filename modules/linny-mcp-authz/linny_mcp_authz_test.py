#!/usr/bin/env python3
"""Tests voor de tokenvalidator. Draait zonder netwerk en zonder Authelia.

    python3 modules/linny-mcp-authz/linny_mcp_authz_test.py
"""

import importlib.util
import os
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent

RESULTS = []


def check(name, condition, detail=""):
    RESULTS.append(bool(condition))
    print(f"  [{'OK  ' if condition else 'FOUT'}] {name}" + (f" -- {detail}" if not condition else ""))


def load_module():
    """De module leest zijn configuratie bij import, dus de omgeving moet staan."""
    secret = Path(tempfile.mkdtemp()) / "secret"
    secret.write_text("geheim\n")
    os.environ.update(
        AUTHZ_INTROSPECTION_URL="https://auth.example.net/api/oidc/introspection",
        AUTHZ_CLIENT_ID="validator",
        AUTHZ_EXPECTED_CLIENT="claude-connector",
        AUTHZ_CLIENT_SECRET_FILE=str(secret),
        AUTHZ_CACHE_TTL="0.2",
    )
    spec = importlib.util.spec_from_file_location("authz", HERE / "linny-mcp-authz.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_parse_bearer(m):
    print("parse_bearer")
    check("gewone header", m.parse_bearer("Bearer abc123") == "abc123")
    check("schema is hoofdletterongevoelig (RFC 7235)", m.parse_bearer("bearer abc") == "abc")
    check("Basic wordt geweigerd", m.parse_bearer("Basic abc") is None)
    check("ontbrekende header", m.parse_bearer(None) is None)
    check("lege header", m.parse_bearer("") is None)
    check("alleen schema", m.parse_bearer("Bearer") is None)
    check("extra veld wordt geweigerd", m.parse_bearer("Bearer a b") is None)


def test_allowed(m):
    print("allowed")
    ok = {"active": True, "client_id": "claude-connector"}
    check("geldig token van de juiste client", m.allowed(ok) is True)
    check("inactief token", m.allowed({**ok, "active": False}) is False)
    # Dit is de belangrijkste: zonder client-check zou élk geldig token van élke
    # client op deze Authelia toegang geven -- ook dat van Wallos.
    check("geldig token van een ANDERE client",
          m.allowed({"active": True, "client_id": "wallos"}) is False)
    check("active ontbreekt", m.allowed({"client_id": "claude-connector"}) is False)
    check("client_id ontbreekt", m.allowed({"active": True}) is False)
    check("active als string telt niet", m.allowed({"active": "true", "client_id": "claude-connector"}) is False)
    check("leeg antwoord", m.allowed({}) is False)


def test_cache(m):
    print("cache")
    cache = m.Cache(0.2)
    check("onbekende sleutel is niet geldig", cache.valid("x") is False)
    cache.remember("x")
    check("na remember wel geldig", cache.valid("x") is True)
    time.sleep(0.25)
    check("na de TTL niet meer geldig", cache.valid("x") is False)
    check("verlopen sleutel is opgeruimd", "x" not in cache._entries)


def test_geen_token_in_cache(m):
    """De sleutel is een digest, nooit het token zelf -- anders staat het
    tokenmateriaal alsnog in het geheugen van een langlopend proces."""
    print("cachesleutel")
    import hashlib
    cache = m.Cache(5)
    token = "authelia_at_geheimpje"
    digest = hashlib.sha256(token.encode()).hexdigest()
    cache.remember(digest)
    check("sleutel is de digest", digest in cache._entries)
    check("token zelf komt er niet in voor", token not in cache._entries)


def main():
    m = load_module()
    test_parse_bearer(m)
    test_allowed(m)
    test_cache(m)
    test_geen_token_in_cache(m)
    print()
    if all(RESULTS):
        print(f"alle {len(RESULTS)} tests geslaagd")
        return 0
    print(f"{RESULTS.count(False)} van de {len(RESULTS)} tests gefaald")
    return 1


if __name__ == "__main__":
    sys.exit(main())
