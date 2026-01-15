#!/usr/bin/env python3
"""
Magister Login Script - Voor op je LAPTOP
Dit script opent een browser om in te loggen en slaat de sessie op.
Kopieer daarna magister_session.json naar je server.
"""

import time
from pathlib import Path
from playwright.sync_api import sync_playwright

MAGISTER_URL = "https://groevenbeek.magister.net"
SESSION_FILE = "magister_session.json"


def login_and_save_session():
    """Log in met browser en sla sessie op"""
    print("\n" + "="*70)
    print("MAGISTER LOGIN - SESSIE GENERATOR")
    print("="*70)
    print("\nDit script opent een browser voor je om in te loggen.")
    print("Na succesvolle login wordt de sessie opgeslagen in:")
    print(f"  → {SESSION_FILE}")
    print("\nKopieer dit bestand daarna naar je server!\n")

    try:
        with sync_playwright() as p:
            print("Browser wordt geopend...")
            browser = p.chromium.launch(headless=False)
            context = browser.new_context()
            page = context.new_page()

            page.goto(MAGISTER_URL)

            # Wacht tot de gebruiker is ingelogd
            afspraken_found = False

            def handle_response(response):
                nonlocal afspraken_found
                if "/afspraken?" in response.url:
                    afspraken_found = True

            page.on("response", handle_response)

            print("⏳ Log in via de browser en wacht tot de agenda pagina laadt...")

            # Wacht max 10 minuten op succesvolle login
            start_time = time.time()
            while not afspraken_found and (time.time() - start_time) < 600:
                page.wait_for_timeout(1000)

            if not afspraken_found:
                print("✗ Timeout: geen agenda data gevonden binnen 10 minuten")
                print("   Zorg dat je volledig ingelogd bent en de agenda pagina laadt")
                browser.close()
                return False

            # Sla de sessie op
            context.storage_state(path=SESSION_FILE)
            print(f"\n✓ Sessie succesvol opgeslagen in: {SESSION_FILE}")

            browser.close()

            print("\n" + "="*70)
            print("VOLGENDE STAPPEN:")
            print("="*70)
            print(f"1. Kopieer {SESSION_FILE} naar je server:")
            print(f"   scp {SESSION_FILE} jouw-server:/pad/naar/magister/")
            print(f"\n2. Start het server script op je server:")
            print(f"   python magister_server.py")
            print("\n" + "="*70)

            return True

    except Exception as e:
        print(f"\n✗ Fout bij inloggen: {e}")
        import traceback
        traceback.print_exc()
        return False


def main():
    session_file = Path(SESSION_FILE)

    if session_file.exists():
        print(f"\n⚠ Let op: {SESSION_FILE} bestaat al!")
        response = input("Wil je opnieuw inloggen? (j/n): ")
        if response.lower() not in ['j', 'ja', 'y', 'yes']:
            print("Geannuleerd.")
            return

    success = login_and_save_session()

    if success:
        print("\n✓ Klaar! Je kunt nu de sessie naar je server kopiëren.")
    else:
        print("\n✗ Login mislukt. Probeer het opnieuw.")


if __name__ == "__main__":
    main()
