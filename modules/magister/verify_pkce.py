#!/usr/bin/env python3
"""
Magister PKCE / refresh-token VERIFICATIE - draai op je LAPTOP (lobos).

Doel: bewijzen (of ontkrachten) dat Magister's IdentityServer voor Groevenbeek
een REFRESH-TOKEN afgeeft via de authorization-code + PKCE + offline_access flow.
Als dat lukt, kan magister_server.py worden omgebouwd naar stille token-refresh
en verdwijnt de ~10-uurs SSO-cliff.

Het opent een echte browser (net als magister_login.py) zodat jij met je PASSKEY
kunt inloggen. Daarna vangt het de authorization `code` op de redirect en wisselt
die in bij /connect/token. Het print of er een refresh_token uitkwam.

Gebruik dezelfde omgeving als magister_login.py (playwright beschikbaar), bv:
    python3 verify_pkce.py
"""

import base64
import hashlib
import json
import secrets
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

from playwright.sync_api import sync_playwright

# ── Parameters (uit de echte login-URL in de service-logs) ────────────────────
AUTHORITY     = "https://accounts.magister.net"
AUTHORIZE_URL = f"{AUTHORITY}/connect/authorize"
TOKEN_URL     = f"{AUTHORITY}/connect/token"

CLIENT_ID     = "M6-groevenbeek.magister.net"
REDIRECT_URI  = "https://groevenbeek.magister.net/oidc/redirect_callback.html"
ACR_VALUES    = "tenant:groevenbeek.magister.net"

# Exact de scopes van de web-client PLUS offline_access (dat is de enige toevoeging
# die een refresh-token mogelijk maakt). Een subset van toegestane scopes mag.
SCOPES = (
    "openid profile offline_access "
    "opp.read calendar.user calendar.ical.user calendar.to-do.user"
)

OUT_FILE = "magister_pkce_result.json"
TIMEOUT_SEC = 300  # 5 min om in te loggen


def b64url(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")


def main() -> int:
    # ── PKCE + state/nonce genereren ─────────────────────────────────────────
    code_verifier = b64url(secrets.token_bytes(64))
    code_challenge = b64url(hashlib.sha256(code_verifier.encode("ascii")).digest())
    state = b64url(secrets.token_bytes(16))
    nonce = b64url(secrets.token_bytes(16))

    params = {
        "client_id": CLIENT_ID,
        "redirect_uri": REDIRECT_URI,
        "response_type": "code",          # <-- code i.p.v. "id_token token" (implicit)
        "response_mode": "query",
        "scope": SCOPES,                  # <-- bevat offline_access
        "state": state,
        "nonce": nonce,
        "code_challenge": code_challenge,
        "code_challenge_method": "S256",
        "acr_values": ACR_VALUES,
    }
    authorize = AUTHORIZE_URL + "?" + urllib.parse.urlencode(params)

    print("=" * 70)
    print("MAGISTER PKCE / REFRESH-TOKEN VERIFICATIE")
    print("=" * 70)
    print(f"\nclient_id    : {CLIENT_ID}")
    print(f"redirect_uri : {REDIRECT_URI}")
    print(f"scopes       : {SCOPES}")
    print("\nEr opent een browser. Log in met je PASSKEY (zoals altijd).")
    print("Na de login vangt dit script de authorization-code automatisch op.\n")

    captured: dict = {}

    def on_request(request):
        url = request.url
        if url.startswith(REDIRECT_URI) and ("code=" in url or "error=" in url):
            q = urllib.parse.urlparse(url).query
            p = urllib.parse.parse_qs(q)
            if "code" in p and "code" not in captured:
                captured["code"] = p["code"][0]
                captured["state"] = p.get("state", [None])[0]
            if "error" in p and "error" not in captured:
                captured["error"] = p["error"][0]
                captured["error_description"] = p.get("error_description", [""])[0]

    try:
        with sync_playwright() as pw:
            browser = pw.chromium.launch(headless=False)
            context = browser.new_context()  # verse context -> echte login
            page = context.new_page()
            page.on("request", on_request)

            page.goto(authorize)

            start = time.time()
            while not captured and (time.time() - start) < TIMEOUT_SEC:
                page.wait_for_timeout(500)

            browser.close()
    except Exception as e:  # noqa: BLE001
        print(f"\n[FOUT] Browser-/loginfase mislukte: {e}")
        return 2

    # ── Resultaat van de authorize-stap ──────────────────────────────────────
    if "error" in captured:
        print("\n[RESULTAAT] IdentityServer weigerde de code-flow voor deze client:")
        print(f"  error             : {captured['error']}")
        print(f"  error_description : {captured.get('error_description', '')}")
        print("\n=> Deze web-client (M6-...) staat waarschijnlijk GEEN authorization_code")
        print("   toe. Dan is de mobiele-app-client nodig (aparte client_id).")
        return 1

    if "code" not in captured:
        print("\n[RESULTAAT] Geen authorization-code opgevangen (timeout of afgebroken).")
        print("   Ben je volledig ingelogd geraakt? Probeer opnieuw.")
        return 1

    if captured.get("state") != state:
        print("\n[WAARSCHUWING] state komt niet overeen (mogelijk onschadelijk), ga door...")

    print(f"\n[OK] Authorization-code opgevangen: {captured['code'][:12]}...")
    print("Inwisselen bij /connect/token ...")

    # ── Code inwisselen voor tokens ──────────────────────────────────────────
    data = urllib.parse.urlencode({
        "grant_type": "authorization_code",
        "code": captured["code"],
        "redirect_uri": REDIRECT_URI,
        "client_id": CLIENT_ID,
        "code_verifier": code_verifier,
    }).encode("ascii")

    req = urllib.request.Request(
        TOKEN_URL,
        data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8", "replace")
        print(f"\n[RESULTAAT] Token-endpoint gaf HTTP {e.code}:")
        print(f"  {err_body}")
        print("\n=> Code-flow niet toegestaan voor deze client, of PKCE/redirect mismatch.")
        return 1
    except Exception as e:  # noqa: BLE001
        print(f"\n[FOUT] Token-request mislukte: {e}")
        return 2

    # Access-token niet volledig loggen; refresh-token is de kernvraag.
    has_refresh = bool(body.get("refresh_token"))
    safe = dict(body)
    for k in ("access_token", "id_token", "refresh_token"):
        if k in safe:
            safe[k] = safe[k][:16] + f"...({len(body[k])} chars)"
    with open(OUT_FILE, "w", encoding="utf-8") as f:
        json.dump(body, f, indent=2)  # volledige tokens hier bewaard voor evt. hergebruik

    print("\n" + "=" * 70)
    print("TOKEN-RESPONSE (ingekort):")
    print(json.dumps(safe, indent=2))
    print("=" * 70)

    if has_refresh:
        print("\n✅ REFRESH-TOKEN AANWEZIG.")
        print(f"   token_type    : {body.get('token_type')}")
        print(f"   expires_in    : {body.get('expires_in')} s (access-token)")
        print(f"   scope         : {body.get('scope')}")
        print(f"\n   Volledige respons opgeslagen in: {OUT_FILE}")
        print("   => De ombouw naar stille refresh in magister_server.py is HAALBAAR.")
        return 0
    else:
        print("\n❌ GEEN refresh-token in de respons (offline_access niet gehonoreerd).")
        print("   => Deze client geeft geen refresh-token; mobiele-app-client nodig.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
