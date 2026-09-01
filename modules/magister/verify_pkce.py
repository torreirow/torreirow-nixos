#!/usr/bin/env python3
"""
Magister PKCE / refresh-token VERIFICATIE - draai op je LAPTOP (lobos).

Doel: bewijzen (of ontkrachten) dat Magister voor Groevenbeek een REFRESH-TOKEN
afgeeft via de authorization-code + PKCE + offline_access flow van de MOBIELE APP
(client_id M6LOAPP). De web-client (M6-groevenbeek.magister.net) doet dit NIET
("unauthorized_client: Invalid grant type"), vandaar de mobiele client.

Parameters afgeleid van de mobiele-app-flow (idiidk/magister-openid):
    authority     https://accounts.magister.net
    client_id     M6LOAPP
    redirect_uri  m6loapp://oauth2redirect/      (custom scheme)
    response_type code id_token                  (hybrid -> code in FRAGMENT)
    scope         openid profile offline_access
    acr_values    tenant:groevenbeek.magister.net
    auth method   none (public client, PKCE)

Het opent een echte browser zodat jij met je PASSKEY via Microsoft-SSO kunt
inloggen. Daarna vangt het de `code` op uit de redirect naar m6loapp://…#code=…
(via de 302 Location-header) en wisselt die in bij /connect/token. Het print of
er een refresh_token uitkwam.

Gebruik dezelfde omgeving als magister_login.py (playwright beschikbaar):
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

# ── Parameters (mobiele-app-client) ───────────────────────────────────────────
AUTHORITY     = "https://accounts.magister.net"
AUTHORIZE_URL = f"{AUTHORITY}/connect/authorize"
TOKEN_URL     = f"{AUTHORITY}/connect/token"

CLIENT_ID     = "M6LOAPP"
REDIRECT_URI  = "m6loapp://oauth2redirect/"
TENANT        = "groevenbeek.magister.net"
ACR_VALUES    = f"tenant:{TENANT}"
RESPONSE_TYPE = "code id_token"
SCOPES        = "openid profile offline_access"

OUT_FILE    = "magister_pkce_result.json"
TIMEOUT_SEC = 300  # 5 min om in te loggen


def b64url(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")


def parse_code(location: str, captured: dict) -> None:
    """Haal code/error uit een redirect-URL (fragment of query)."""
    if not location:
        return
    frag = ""
    if "#" in location:
        frag = location.split("#", 1)[1]
    query = urllib.parse.urlparse(location).query
    for blob in (frag, query):
        if not blob:
            continue
        p = urllib.parse.parse_qs(blob)
        if "code" in p and "code" not in captured:
            captured["code"] = p["code"][0]
            captured["state"] = p.get("state", [None])[0]
        if "error" in p and "error" not in captured:
            captured["error"] = p["error"][0]
            captured["error_description"] = p.get("error_description", [""])[0]


def main() -> int:
    code_verifier = b64url(secrets.token_bytes(64))
    code_challenge = b64url(hashlib.sha256(code_verifier.encode("ascii")).digest())
    state = b64url(secrets.token_bytes(16))
    nonce = b64url(secrets.token_bytes(16))

    params = {
        "client_id": CLIENT_ID,
        "redirect_uri": REDIRECT_URI,
        "response_type": RESPONSE_TYPE,
        "scope": SCOPES,
        "state": state,
        "nonce": nonce,
        "code_challenge": code_challenge,
        "code_challenge_method": "S256",
        "acr_values": ACR_VALUES,
        "prompt": "select_account",
    }
    authorize = AUTHORIZE_URL + "?" + urllib.parse.urlencode(params)

    print("=" * 70)
    print("MAGISTER PKCE / REFRESH-TOKEN VERIFICATIE  (mobiele client M6LOAPP)")
    print("=" * 70)
    print(f"\nclient_id    : {CLIENT_ID}")
    print(f"redirect_uri : {REDIRECT_URI}")
    print(f"scopes       : {SCOPES}")
    print("\nEr opent een browser. Log in met je PASSKEY (Microsoft-SSO), zoals altijd.")
    print("Na de login vangt dit script de authorization-code automatisch op.\n")

    captured: dict = {}

    def on_response(resp):
        try:
            if resp.status in (301, 302, 303, 307, 308):
                loc = resp.headers.get("location", "")
                if "m6loapp" in loc or "code=" in loc or "error=" in loc:
                    parse_code(loc, captured)
        except Exception:  # noqa: BLE001
            pass

    def on_request(request):
        url = request.url
        if url.startswith("m6loapp://") or "code=" in url or "error=" in url:
            parse_code(url, captured)

    def on_request_failed(request):
        # Custom-scheme navigatie mislukt in Chromium; url kan de code bevatten.
        if request.url.startswith("m6loapp://"):
            parse_code(request.url, captured)

    try:
        with sync_playwright() as pw:
            browser = pw.chromium.launch(headless=False)
            context = browser.new_context()  # verse context -> echte login
            page = context.new_page()
            page.on("response", on_response)
            page.on("request", on_request)
            page.on("requestfailed", on_request_failed)

            try:
                page.goto(authorize)
            except Exception:  # noqa: BLE001
                pass  # custom-scheme redirect kan goto laten falen; handlers vangen de code

            start = time.time()
            while "code" not in captured and "error" not in captured \
                    and (time.time() - start) < TIMEOUT_SEC:
                page.wait_for_timeout(500)

            browser.close()
    except Exception as e:  # noqa: BLE001
        # Als we de code al hebben is een browser-fout onschadelijk.
        if "code" not in captured:
            print(f"\n[FOUT] Browser-/loginfase mislukte: {e}")
            return 2

    # ── Resultaat authorize-stap ─────────────────────────────────────────────
    if "error" in captured:
        print("\n[RESULTAAT] IdentityServer weigerde de flow:")
        print(f"  error             : {captured['error']}")
        print(f"  error_description : {captured.get('error_description', '')}")
        return 1

    if "code" not in captured:
        print("\n[RESULTAAT] Geen authorization-code opgevangen (timeout of afgebroken).")
        print("   Ben je volledig ingelogd geraakt? Zag je een 'kan m6loapp:// niet openen'")
        print("   melding? Dat is juist goed — de code zit dan in de redirect. Probeer opnieuw.")
        return 1

    if captured.get("state") not in (None, state):
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
        return 1
    except Exception as e:  # noqa: BLE001
        print(f"\n[FOUT] Token-request mislukte: {e}")
        return 2

    has_refresh = bool(body.get("refresh_token"))
    safe = dict(body)
    for k in ("access_token", "id_token", "refresh_token"):
        if k in safe:
            safe[k] = safe[k][:16] + f"...({len(body[k])} chars)"
    with open(OUT_FILE, "w", encoding="utf-8") as f:
        json.dump(body, f, indent=2)  # volledige tokens; staat in .gitignore

    print("\n" + "=" * 70)
    print("TOKEN-RESPONSE (ingekort):")
    print(json.dumps(safe, indent=2))
    print("=" * 70)

    if has_refresh:
        print("\n✅ REFRESH-TOKEN AANWEZIG.")
        print(f"   token_type : {body.get('token_type')}")
        print(f"   expires_in : {body.get('expires_in')} s (access-token)")
        print(f"   scope      : {body.get('scope')}")
        print(f"\n   Volledige respons opgeslagen in: {OUT_FILE}")
        print("   => Ombouw van magister_server.py naar stille refresh is HAALBAAR.")
        return 0

    print("\n❌ GEEN refresh-token in de respons (offline_access niet gehonoreerd).")
    return 1


if __name__ == "__main__":
    sys.exit(main())
