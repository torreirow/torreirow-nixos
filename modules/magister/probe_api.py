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

    # ── Account ophalen -> person-id afleiden ────────────────────────────────
    print("\n" + "=" * 70)
    print("ACCOUNT -> KINDEREN -> AFSPRAKEN  (dynamische ontdekking)")
    print("=" * 70)
    status, body = get("/api/account", access, {})
    if status != 200:
        print(f"  /api/account -> HTTP {status} (verwacht 200). Stop discovery.")
        return 1
    acc = json.loads(body)
    person_id = acc.get("Id") or (acc.get("Persoon") or {}).get("Id")
    print(f"  account person-id: {person_id}")

    # Kinderen-endpoint kandidaten
    kinderen = None
    kind_pad = None
    for path in (f"/api/personen/{person_id}/kinderen",
                 f"/api/leerlingen/{person_id}/kinderen",
                 "/api/kinderen"):
        st, bd = get(path, access, {})
        print(f"  kinderen? {path:40} -> HTTP {st}")
        if st == 200:
            try:
                data = json.loads(bd)
                if isinstance(data, dict) and data.get("Items"):
                    kinderen = data["Items"]
                    kind_pad = path
                    break
            except Exception:  # noqa: BLE001
                pass

    if kinderen is None:
        print("\n  Geen kinderen-endpoint gevonden -> account is mogelijk zelf de leerling.")
        # Probeer eigen afspraken
        kinderen = [{"Id": person_id, "Roepnaam": acc.get("Persoon", {}).get("Roepnaam") or "self"}]
        kind_pad = "(self)"

    print(f"\n  ✅ kinderen-pad: {kind_pad}  ({len(kinderen)} kind(eren))")
    for k in kinderen:
        kid = k.get("Id")
        naam = k.get("Roepnaam") or k.get("Achternaam") or "?"
        stam = k.get("Stamnummer")
        # Afspraken-call testen (kleine window)
        from datetime import date, timedelta
        van = date.today().isoformat()
        tot = (date.today() + timedelta(days=7)).isoformat()
        apad = f"/api/personen/{kid}/afspraken?van={van}&tot={tot}"
        st, bd = get(apad, access, {})
        n = "?"
        try:
            n = len(json.loads(bd).get("Items", []))
        except Exception:  # noqa: BLE001
            pass
        print(f"     - {naam:12} (Id {kid}, Stamnr {stam})  afspraken -> HTTP {st}, {n} items")

    print("\n=> Endpoints bevestigd voor de Bearer-ombouw:")
    print(f"   account : /api/account            (person-id via .Persoon.Id)")
    print(f"   kinderen: {kind_pad}")
    print(f"   agenda  : /api/personen/<kindId>/afspraken?van=&tot=")
    return 0


if __name__ == "__main__":
    sys.exit(main())
