#!/usr/bin/env python3
"""
Magister Server Script - Voor op je SERVER (headless)
Dit script draait zonder GUI en gebruikt alleen magister_session.json
"""

import time
import os
import subprocess
from pathlib import Path
from datetime import datetime, timedelta
from playwright.sync_api import sync_playwright
from ics import Calendar, Event
from dateutil import parser
from bs4 import BeautifulSoup


# Configuratie
MAGISTER_URL = "https://groevenbeek.magister.net"
SESSION_FILE = "magister_session.json"
ICAL_FILE = "magister.ics"
KEEP_ALIVE_INTERVAL = 28 * 60  # 28 minuten in seconden


def find_chromium_executable():
    """Vind Chromium executable op NixOS of standaard systeem"""
    # Probeer NixOS locaties
    nix_paths = [
        "/run/current-system/sw/bin/chromium",
        "/etc/profiles/per-user/*/bin/chromium",
        subprocess.run(["which", "chromium"], capture_output=True, text=True).stdout.strip(),
        subprocess.run(["which", "chromium-browser"], capture_output=True, text=True).stdout.strip(),
    ]

    for path in nix_paths:
        if path and Path(path).exists():
            print(f"✓ Chromium gevonden: {path}")
            return path

    # Fallback naar None (gebruik Playwright default)
    print("⚠ Geen NixOS Chromium gevonden, gebruik Playwright default")
    return None


class MagisterServerClient:
    def __init__(self):
        self.session_file = Path(SESSION_FILE)
        self.afspraken_data = None
        self.kinderen = []
        self.chromium_path = find_chromium_executable()

    def get_browser_launch_options(self):
        """Geef browser launch opties terug, NixOS-compatible"""
        options = {"headless": True}
        if self.chromium_path:
            options["executable_path"] = self.chromium_path
        return options

    def session_exists(self):
        """Check of er een opgeslagen sessie bestaat"""
        return self.session_file.exists()

    def fetch_kinderen(self):
        """Haal lijst van kinderen op van het ouderaccount"""
        if not self.session_exists():
            print("✗ Geen sessie gevonden")
            return None

        try:
            with sync_playwright() as p:
                browser = p.chromium.launch(**self.get_browser_launch_options())
                context = browser.new_context(storage_state=str(self.session_file))
                page = context.new_page()

                kinderen_response = None
                account_id = None

                def handle_response(response):
                    nonlocal kinderen_response, account_id
                    # Zoek eerst het account ID
                    if "/api/account?" in response.url and not account_id:
                        try:
                            data = response.json()
                            account_id = data.get('Id')
                        except:
                            pass
                    # Zoek kinderen endpoint
                    if "/kinderen" in response.url:
                        try:
                            kinderen_response = response.json()
                        except:
                            pass

                page.on("response", handle_response)

                # Navigeer naar hoofdpagina om account info op te halen
                page.goto(MAGISTER_URL, wait_until="networkidle")
                page.wait_for_timeout(3000)

                browser.close()

                if kinderen_response and 'Items' in kinderen_response:
                    self.kinderen = kinderen_response['Items']
                    print(f"✓ Gevonden: {len(self.kinderen)} kind(eren)")
                    for kind in self.kinderen:
                        print(f"  - {kind['Roepnaam']} (ID: {kind['Id']}, Stamnr: {kind['Stamnummer']})")
                    return self.kinderen
                else:
                    print("⚠ Geen kinderen gevonden, gebruik standaard account")
                    return None

        except Exception as e:
            print(f"✗ Fout bij ophalen kinderen: {e}")
            return None

    def test_session(self):
        """Test of de opgeslagen sessie nog geldig is"""
        if not self.session_exists():
            return False

        try:
            print("Testen van sessie...")
            with sync_playwright() as p:
                browser = p.chromium.launch(**self.get_browser_launch_options())
                context = browser.new_context(storage_state=str(self.session_file))
                page = context.new_page()

                # Vang alle responses en errors
                afspraken_response = []
                error_responses = []

                def handle_response(response):
                    if "/afspraken?" in response.url:
                        afspraken_response.append(response)
                    # Check voor 401/403 errors (unauthorized)
                    if response.status in [401, 403]:
                        error_responses.append({
                            'url': response.url,
                            'status': response.status
                        })
                        print(f"  ⚠ HTTP {response.status} op {response.url}")

                page.on("response", handle_response)

                # Probeer naar hoofdpagina te gaan
                response = page.goto(MAGISTER_URL, wait_until="networkidle", timeout=30000)

                page.wait_for_timeout(2000)

                # Check of we doorgestuurd worden naar login pagina
                current_url = page.url

                if "login" in current_url.lower() or "oidc" in current_url.lower():
                    print("  ✗ Doorgestuurd naar login pagina - sessie ongeldig")
                    browser.close()
                    return False

                browser.close()

                if error_responses:
                    print(f"✗ Sessie is niet geldig ({len(error_responses)} auth errors)")
                    return False
                elif afspraken_response:
                    print("✓ Sessie is nog geldig")
                    return True
                else:
                    # Probeer API call om te valideren
                    print("  Geen afspraken response, probeer directe API test...")
                    return self.test_session_api()

        except Exception as e:
            print(f"⚠ Fout bij testen sessie: {e}")
            import traceback
            traceback.print_exc()
            return False

    def test_session_api(self):
        """Test sessie via directe API call"""
        try:
            with sync_playwright() as p:
                browser = p.chromium.launch(**self.get_browser_launch_options())
                context = browser.new_context(storage_state=str(self.session_file))
                page = context.new_page()

                # Laad eerst hoofdpagina
                page.goto(f"{MAGISTER_URL}/magister/", wait_until="networkidle")
                page.wait_for_timeout(1000)

                # Probeer account API aan te roepen
                api_url = f"{MAGISTER_URL}/api/account"
                result = page.evaluate(f"""
                    async () => {{
                        try {{
                            const response = await fetch('{api_url}');
                            return {{
                                status: response.status,
                                ok: response.ok
                            }};
                        }} catch (e) {{
                            return {{ error: e.message }};
                        }}
                    }}
                """)

                browser.close()

                if result.get('ok'):
                    print("✓ Sessie is geldig (via API)")
                    return True
                else:
                    print(f"✗ API test mislukt: status {result.get('status')}")
                    return False

        except Exception as e:
            print(f"✗ API test error: {e}")
            return False

    def fetch_afspraken(self, days=7, persoon_id=None):
        """Haal afspraken op met Playwright voor een bepaald aantal dagen en specifiek persoon"""
        if not self.session_exists():
            print("✗ Geen sessie gevonden")
            return None

        try:
            with sync_playwright() as p:
                browser = p.chromium.launch(**self.get_browser_launch_options())
                context = browser.new_context(storage_state=str(self.session_file))
                page = context.new_page()

                # Bereken start en eind datum voor de week
                today = datetime.now()
                start_of_week = today - timedelta(days=today.weekday())  # Maandag
                end_of_week = start_of_week + timedelta(days=days - 1)

                van_datum = start_of_week.strftime('%Y-%m-%d')
                tot_datum = end_of_week.strftime('%Y-%m-%d')

                # Nieuwe aanpak: DIRECT de API aanroepen via page.evaluate
                if persoon_id:
                    print(f"  Direct API call naar /api/personen/{persoon_id}/afspraken")

                    # Eerst een pagina laden om cookies/sessie te initialiseren
                    page.goto(f"{MAGISTER_URL}/magister/", wait_until="networkidle")
                    page.wait_for_timeout(1000)

                    # Nu direct API call doen via fetch in de browser context
                    api_url = f"{MAGISTER_URL}/api/personen/{persoon_id}/afspraken?status=1&tot={tot_datum}&van={van_datum}"
                    print(f"  API URL: {api_url}")

                    try:
                        result = page.evaluate(f"""
                            async () => {{
                                const response = await fetch('{api_url}');
                                if (!response.ok) {{
                                    throw new Error('API call failed: ' + response.status);
                                }}
                                return await response.json();
                            }}
                        """)

                        browser.close()

                        if result and 'Items' in result:
                            print(f"✓ Afspraken opgehaald via API: {len(result.get('Items', []))} items ({van_datum} t/m {tot_datum})")
                            return result
                        else:
                            print("✗ Geen items in API response")
                            return None

                    except Exception as api_error:
                        print(f"✗ API call mislukt: {api_error}")
                        browser.close()
                        return None

                else:
                    # Fallback naar oude methode voor default account
                    afspraken_response = []

                    def handle_response(response):
                        if "/afspraken?" in response.url:
                            afspraken_response.append(response)

                    page.on("response", handle_response)

                    agenda_url = f"{MAGISTER_URL}/magister/#/agenda?van={van_datum}&tot={tot_datum}"
                    page.goto(agenda_url, wait_until="networkidle")
                    page.wait_for_timeout(5000)

                    if not afspraken_response:
                        page.goto(f"{MAGISTER_URL}/magister/#/agenda", wait_until="networkidle")
                        page.wait_for_timeout(5000)

                    if not afspraken_response:
                        print("✗ Geen /afspraken response gevonden")
                        browser.close()
                        return None

                    # Verzamel alle afspraken
                    all_items = []
                    for response in afspraken_response:
                        try:
                            data = response.json()
                            if 'Items' in data:
                                all_items.extend(data['Items'])
                        except:
                            pass

                    combined_data = {'Items': all_items}
                    browser.close()

                    print(f"✓ Afspraken opgehaald: {len(combined_data.get('Items', []))} items ({van_datum} t/m {tot_datum})")
                    return combined_data

        except Exception as e:
            print(f"✗ Fout bij ophalen afspraken: {e}")
            return None

    def export_to_ical(self, appointments, output_file=ICAL_FILE):
        """Exporteer afspraken naar iCal formaat"""
        if not appointments or 'Items' not in appointments:
            print("✗ Geen afspraken om te exporteren")
            return False

        try:
            cal = Calendar()

            for item in appointments['Items']:
                e = Event()

                # Titel: vakken + omschrijving
                vakken = ", ".join(v["Naam"] for v in item.get("Vakken", []))
                titel = item.get("Omschrijving", "Geen titel")
                if vakken:
                    titel = f"{vakken} – {titel}"

                e.name = titel
                e.begin = parser.isoparse(item["Start"])
                e.end = parser.isoparse(item["Einde"])

                # Locatie
                lokalen = ", ".join(l["Naam"] for l in item.get("Lokalen", []))
                e.location = lokalen or item.get("Lokatie")

                # Beschrijving
                beschrijving = []
                if item.get("Docenten"):
                    docenten = ", ".join(d["Naam"] for d in item["Docenten"])
                    beschrijving.append(f"Docent(en): {docenten}")

                if item.get("Inhoud"):
                    soup = BeautifulSoup(item["Inhoud"], "html.parser")
                    beschrijving.append(soup.get_text())

                e.description = "\n".join(beschrijving)
                e.uid = f"magister-{item['Id']}@groevenbeek"

                cal.events.add(e)

            # Schrijf naar bestand
            with open(output_file, "w") as f:
                f.writelines(cal)

            print(f"✓ iCal bestand bijgewerkt: {output_file} ({len(cal.events)} afspraken)")
            return True

        except Exception as e:
            print(f"✗ Fout bij exporteren naar iCal: {e}")
            return False


def main():
    """Hoofdfunctie voor server"""
    print("\n" + "="*70)
    print("MAGISTER SERVER - HEADLESS MODE (MULTI-KIND)")
    print("="*70)

    client = MagisterServerClient()

    # Check of sessie bestaat
    if not client.session_exists():
        print(f"\n✗ Geen sessie gevonden: {SESSION_FILE}")
        print("\nVoer de volgende stappen uit:")
        print("1. Draai magister_login.py op je laptop")
        print(f"2. Kopieer {SESSION_FILE} naar deze server")
        print("3. Start dit script opnieuw\n")
        import sys
        sys.exit(1)  # Exit met code 1 = sessie probleem

    print(f"\n✓ Sessie bestand gevonden: {SESSION_FILE}")

    # Test sessie
    if not client.test_session():
        print("\n✗ Sessie is niet meer geldig!")
        print("\nDe sessie is verlopen. Voer de volgende stappen uit:")
        print("1. Draai magister_login.py op je laptop (opnieuw inloggen)")
        print(f"2. Kopieer het nieuwe {SESSION_FILE} naar deze server")
        print("3. Start dit script opnieuw\n")
        import sys
        sys.exit(1)  # Exit met code 1 = sessie probleem

    # Haal lijst van kinderen op
    print("\n=== Kinderen detecteren ===")
    kinderen = client.fetch_kinderen()

    if not kinderen:
        print("⚠ Geen kinderen gevonden, gebruik standaard methode")
        # Fallback naar oude methode
        appointments = client.fetch_afspraken(days=7)
        if appointments:
            client.export_to_ical(appointments)
        return

    # Haal voor elk kind de agenda op
    print("\n=== Agenda's ophalen ===")
    kind_data = {}

    for kind in kinderen:
        naam = kind['Roepnaam']
        persoon_id = kind['Id']

        print(f"\n→ {naam} (ID: {persoon_id})...")
        appointments = client.fetch_afspraken(days=7, persoon_id=persoon_id)

        if appointments:
            # Maak bestandsnaam: magister_<naam>.ics
            output_file = f"magister_{naam.lower()}.ics"
            client.export_to_ical(appointments, output_file)
            kind_data[naam] = {
                'id': persoon_id,
                'file': output_file
            }
        else:
            print(f"  ⚠ Kon agenda voor {naam} niet ophalen")

    if not kind_data:
        print("\n✗ Kon geen agenda's ophalen voor kinderen")
        return

    # Keep-alive loop
    print(f"\n=== Keep-alive gestart (elke {KEEP_ALIVE_INTERVAL//60} minuten) ===")
    print(f"Het script update {len(kind_data)} agenda bestand(en) automatisch")
    print("Druk op Ctrl+C om te stoppen\n")

    try:
        while True:
            time.sleep(KEEP_ALIVE_INTERVAL)

            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            print(f"\n[{timestamp}] Keep-alive: agenda's ophalen...")

            # Update elk kind
            for naam, info in kind_data.items():
                print(f"  → {naam}...", end=" ")
                appointments = client.fetch_afspraken(days=7, persoon_id=info['id'])

                if appointments:
                    client.export_to_ical(appointments, info['file'])
                else:
                    print("⚠ Mislukt")

    except KeyboardInterrupt:
        print("\n\n✓ Server gestopt door gebruiker")


if __name__ == "__main__":
    main()
