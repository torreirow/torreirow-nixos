#!/usr/bin/env python3
"""
Magister refresh-token TEST - draai op lobos (of malandro) NA verify_pkce.py.

Leest magister_pkce_result.json en beantwoordt drie vragen die het opslagontwerp
van de ombouw bepalen:
  1. Werkt de access_token tegen de Magister-API? (Bearer -> /api/account)
  2. Werkt grant_type=refresh_token? (nieuw access_token?)
  3. ROULEERT het refresh-token bij gebruik? (belangrijk: dan moet de server het
     nieuwe token telkens wegschrijven i.p.v. een read-only agenix-secret)

Puur HTTP; geen browser/passkey nodig.
    python3 refresh_test.py
"""

import json
import sys
import urllib.error
import urllib.parse
import urllib.request

AUTHORITY  = "https://accounts.magister.net"
TOKEN_URL  = f"{AUTHORITY}/connect/token"
CLIENT_ID  = "M6LOAPP"
TENANT_URL = "https://groevenbeek.magister.net"
IN_FILE    = "magister_pkce_result.json"


def api_get(path: str, access_token: str):
    req = urllib.request.Request(
        TENANT_URL + path,
        headers={"Authorization": f"Bearer {access_token}", "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, r.read().decode("utf-8", "replace")[:300]
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")[:300]
    except Exception as e:  # noqa: BLE001
        return None, str(e)


def main() -> int:
    try:
        tok = json.load(open(IN_FILE, encoding="utf-8"))
    except Exception as e:  # noqa: BLE001
        print(f"[FOUT] Kan {IN_FILE} niet lezen: {e}")
        return 2

    access = tok.get("access_token")
    refresh = tok.get("refresh_token")
    if not refresh:
        print("[FOUT] Geen refresh_token in het bestand. Draai eerst verify_pkce.py.")
        return 2

    print("=" * 70)
    print("1) API-test met huidige access_token  (GET /api/account)")
    print("=" * 70)
    status, body = api_get("/api/account", access)
    print(f"   HTTP {status}")
    print(f"   body: {body}")
    print(f"   => access_token {'WORDT geaccepteerd' if status == 200 else 'NIET geaccepteerd'} door de API\n")

    print("=" * 70)
    print("2+3) Refresh-token inwisselen  (grant_type=refresh_token)")
    print("=" * 70)
    data = urllib.parse.urlencode({
        "grant_type": "refresh_token",
        "refresh_token": refresh,
        "client_id": CLIENT_ID,
    }).encode("ascii")
    req = urllib.request.Request(
        TOKEN_URL, data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            new = json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        print(f"   [RESULTAAT] HTTP {e.code}: {e.read().decode('utf-8', 'replace')[:300]}")
        print("   => refresh werkt (nog) niet met deze parameters.")
        return 1
    except Exception as e:  # noqa: BLE001
        print(f"   [FOUT] {e}")
        return 2

    new_access = new.get("access_token")
    new_refresh = new.get("refresh_token")
    print(f"   nieuw access_token : {'JA' if new_access else 'nee'} (expires_in={new.get('expires_in')})")
    print(f"   scope              : {new.get('scope')}")

    if new_refresh is None:
        print("   refresh_token in respons: NEE -> zelfde token blijft geldig (geen rotatie)")
        rotates = False
    elif new_refresh == refresh:
        print("   refresh_token in respons: identiek -> GEEN rotatie")
        rotates = False
    else:
        print("   refresh_token in respons: NIEUW -> ROTATIE (oude vervalt)")
        rotates = True

    # Test de nieuwe access_token ook even
    if new_access:
        status2, _ = api_get("/api/account", new_access)
        print(f"   API-test met NIEUW access_token: HTTP {status2}")

    print("\n" + "=" * 70)
    print("CONCLUSIE VOOR HET ONTWERP")
    print("=" * 70)
    if rotates:
        print("• Refresh-token ROULEERT -> server moet na elke refresh het NIEUWE refresh-token")
        print("  wegschrijven naar een schrijfbaar state-bestand (bv. /var/lib/magister/token.json).")
        print("  Agenix-secret alleen als EENMALIGE startwaarde (seed).")
    else:
        print("• Refresh-token roteert NIET -> één vast refresh-token; agenix-secret volstaat.")
    print("• API accepteert Bearer-token -> magister_server.py kan cookie-scraping vervangen door")
    print("  directe API-calls met Authorization: Bearer <access_token>.")

    # Bewaar de ververste tokens (handig als startpunt / bij rotatie)
    with open(IN_FILE, "w", encoding="utf-8") as f:
        json.dump(new, f, indent=2)
    print(f"\n(Verse tokens teruggeschreven naar {IN_FILE}.)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
