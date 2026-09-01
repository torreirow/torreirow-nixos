#!/usr/bin/env python3
"""
Magister API-probe - draai op lobos NA verify_pkce.py / refresh_test.py.

De /api/account-call gaf HTTP 500 met een Bearer-token. Deze probe zoekt uit
(a) wat er IN de access-token zit (aud/iss/scope -> audience-mismatch?) en
(b) welk endpoint wél 200 geeft, zodat de ombouw de juiste call gebruikt.

Doet alleen GET's (rouleert niets). Draai binnen het uur (verse access_token).
    python3 probe_api.py
"""

import base64
import json
import sys
import urllib.error
import urllib.request

TENANT_URL = "https://groevenbeek.magister.net"
IN_FILE    = "magister_pkce_result.json"

# Endpoints die het cookie-pad ooit gebruikte + logische alternatieven.
ENDPOINTS = [
    "/api/account",
    "/api/sessies/huidige",
    "/api/personen",
    "/api/leerlingen",
    "/api/kinderen",
    "/api/account/kinderen",
    "/api/versie",
]

# Twee header-varianten: kaal, en app-achtig (soms eist Magister een UA / client-id).
HEADER_VARIANTS = {
    "kaal": {},
    "app-achtig": {
        "User-Agent": "Magister/main.ioAppStore (iPhone; iOS)",
        "X-API-Client-ID": "M6LOAPP",
    },
}


def b64url_decode(seg: str) -> bytes:
    return base64.urlsafe_b64decode(seg + "=" * (-len(seg) % 4))


def decode_jwt(token: str):
    try:
        parts = token.split(".")
        if len(parts) < 2:
            return None
        return json.loads(b64url_decode(parts[1]))
    except Exception:  # noqa: BLE001
        return None


def get(path: str, token: str, extra: dict):
    headers = {"Authorization": f"Bearer {token}", "Accept": "application/json"}
    headers.update(extra)
    req = urllib.request.Request(TENANT_URL + path, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")
    except Exception as e:  # noqa: BLE001
        return None, str(e)


def main() -> int:
    try:
        tok = json.load(open(IN_FILE, encoding="utf-8"))
    except Exception as e:  # noqa: BLE001
        print(f"[FOUT] Kan {IN_FILE} niet lezen: {e}")
        return 2

    access = tok.get("access_token")
    if not access:
        print("[FOUT] Geen access_token in het bestand.")
        return 2

    print("=" * 70)
    print("ACCESS-TOKEN CLAIMS (payload)")
    print("=" * 70)
    payload = decode_jwt(access)
    if payload:
        for key in ("iss", "aud", "client_id", "scope", "sub", "name",
                    "preferred_username", "tenant", "exp"):
            if key in payload:
                print(f"  {key:20}: {payload[key]}")
        overige = [k for k in payload if k not in {
            "iss", "aud", "client_id", "scope", "sub", "name",
            "preferred_username", "tenant", "exp", "iat", "nbf", "auth_time"}]
        if overige:
            print(f"  (overige claims): {', '.join(overige)}")
    else:
        print("  (kon JWT niet decoderen)")

    print("\n" + "=" * 70)
    print("ENDPOINT-PROBE  (Bearer, GET)")
    print("=" * 70)
    winners = []
    for path in ENDPOINTS:
        for vname, extra in HEADER_VARIANTS.items():
            status, body = get(path, access, extra)
            snippet = body[:120].replace("\n", " ")
            print(f"  [{vname:10}] {path:24} -> HTTP {status}  {snippet}")
            if status == 200:
                winners.append((path, vname))
        print()

    print("=" * 70)
    if winners:
        print("✅ WERKENDE endpoints (HTTP 200):")
        for path, vname in winners:
            print(f"   {path}   (headers: {vname})")
        print("\n=> magister_server.py kan deze call met Bearer gebruiken.")
    else:
        print("❌ Geen enkel endpoint gaf 200.")
        print("   Kijk naar de `aud`/`scope` hierboven: als aud NIET de tenant/API is,")
        print("   heeft de M6LOAPP-token de verkeerde audience en moeten we of extra")
        print("   scopes aanvragen, of het token via een andere route inruilen.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
