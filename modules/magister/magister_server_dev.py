#!/usr/bin/env python3
"""
Magister Server Script - Voor op je SERVER (headless) - DEV VERSION
Dit script draait zonder GUI en gebruikt alleen magister_session.json
Met logging naar /var/log/magister.log
"""

import time
import os
import json
import subprocess
import logging
from pathlib import Path
from datetime import datetime, timedelta
from playwright.sync_api import sync_playwright
from ics import Calendar, Event
from dateutil import parser
from bs4 import BeautifulSoup


# Configuratie
MAGISTER_URL = "https://groevenbeek.magister.net"
OUTPUT_DIR = "/var/lib/magister"  # Directory waar .ics bestanden worden geschreven
SESSION_FILE = f"{OUTPUT_DIR}/magister_session.json"  # Sessie bestand in OUTPUT_DIR
ICAL_FILE = "magister.ics"
KEEP_ALIVE_INTERVAL = 10 * 60  # 10 minuten in seconden
LOG_FILE = "/var/log/magister.log"

# Logging configuratie
def setup_logging():
    """Setup logging naar file en console"""
    global LOG_FILE

    # Test of we naar /var/log kunnen schrijven
    try:
        # Probeer een test file te schrijven
        test_file = Path(LOG_FILE)
        test_file.parent.mkdir(parents=True, exist_ok=True)
        test_file.touch()
    except (PermissionError, OSError):
        # Fallback naar local directory als we geen rechten hebben
        LOG_FILE = "./magister.log"
        print(f"⚠ Geen write permissie voor /var/log, gebruik {LOG_FILE}")

    # Configureer logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s [%(levelname)s] %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S',
        handlers=[
            logging.FileHandler(LOG_FILE, encoding='utf-8'),
            logging.StreamHandler()  # Ook naar console
        ]
    )
    return logging.getLogger(__name__)

logger = setup_logging()


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
            logger.info(f"✓ Chromium gevonden: {path}")
            return path

    # Fallback naar None (gebruik Playwright default)
    logger.warning("⚠ Geen NixOS Chromium gevonden, gebruik Playwright default")
    return None


def generate_index_html(domain="agenda.toorren.net"):
    """Genereer index.html met lijst van beschikbare calendars"""
    try:
        # Zoek alle magister_*.ics bestanden in OUTPUT_DIR
        ics_files = sorted(Path(OUTPUT_DIR).glob("magister_*.ics"))

        # Huidige timestamp voor footer
        update_timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

        # Start HTML
        html = """<!DOCTYPE html>
<html>
<head>
  <title>Magister Agenda Feeds</title>
  <style>
    body { font-family: sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
    h1 { color: #333; }
    .feed { background: #f5f5f5; padding: 15px; margin: 10px 0; border-radius: 5px; }
    .url { background: #fff; padding: 10px; border: 1px solid #ddd; border-radius: 3px;
           font-family: monospace; word-break: break-all; }
    code { background: #e0e0e0; padding: 2px 5px; border-radius: 3px; }
    .no-feeds { background: #fff3cd; padding: 20px; margin: 20px 0; border-radius: 5px;
                border: 1px solid #ffc107; color: #856404; }
    .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd;
              color: #666; font-size: 0.9em; }
  </style>
</head>
<body>
  <h1>Magister Agenda Feeds</h1>
"""

        if not ics_files:
            # Geen feeds beschikbaar
            html += """  <div class="no-feeds">
    <h2>Geen iCalendar feeds beschikbaar</h2>
    <p>Er zijn momenteel geen agenda feeds gevonden. Dit kan betekenen dat:</p>
    <ul>
      <li>De synchronisatie nog niet is gestart</li>
      <li>Er een probleem is met de sessie</li>
      <li>De service nog bezig is met het ophalen van data</li>
    </ul>
    <p>Controleer de service logs voor meer informatie.</p>
  </div>
"""
            logger.warning("⚠ Geen .ics bestanden gevonden, genereer index.html zonder feeds")
        else:
            # Feeds beschikbaar
            html += "  <p>Beschikbare iCalendar feeds:</p>\n"

            # Voeg elke calendar toe
            for ics_file in ics_files:
                naam = ics_file.stem.replace("magister_", "")
                bestandsnaam = ics_file.name  # magister_naam.ics
                html += f"""  <div class="feed">
    <h2>{naam}</h2>
    <div class="url">https://{domain}/calendars/{bestandsnaam}</div>
    <p>Gebruik deze URL in Google Calendar via <code>Toevoegen</code> → <code>Via URL</code></p>
  </div>
"""

        # Sluit HTML af met footer
        html += f"""  <div class="footer">
    <p><strong>Updates:</strong> Elke 10 minuten</p>
    <p><strong>Laatste update:</strong> {update_timestamp}</p>
  </div>
</body>
</html>
"""

        # Schrijf naar bestand in OUTPUT_DIR
        index_path = Path(OUTPUT_DIR) / "index.html"
        with open(index_path, "w") as f:
            f.write(html)

        logger.info(f"✓ index.html gegenereerd met {len(ics_files)} calendar(s) in {OUTPUT_DIR}")
        return True

    except Exception as e:
        logger.error(f"✗ Fout bij genereren index.html: {e}", exc_info=True)
        return False


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
            logger.error("✗ Geen sessie gevonden")
            return None

        try:
            logger.info("Ophalen lijst kinderen...")
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
                    logger.info(f"✓ Gevonden: {len(self.kinderen)} kind(eren)")
                    for kind in self.kinderen:
                        logger.info(f"  - {kind['Roepnaam']} (ID: {kind['Id']}, Stamnr: {kind['Stamnummer']})")
                    return self.kinderen
                else:
                    logger.warning("⚠ Geen kinderen gevonden, gebruik standaard account")
                    return None

        except Exception as e:
            logger.error(f"✗ Fout bij ophalen kinderen: {e}", exc_info=True)
            return None

    def test_session(self):
        """Test of de opgeslagen sessie nog geldig is"""
        if not self.session_exists():
            return False

        try:
            logger.info("Testen van sessie...")
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
                        logger.warning(f"  ⚠ HTTP {response.status} op {response.url}")

                page.on("response", handle_response)

                # Probeer naar hoofdpagina te gaan
                response = page.goto(MAGISTER_URL, wait_until="networkidle", timeout=30000)

                page.wait_for_timeout(2000)

                # Check of we doorgestuurd worden naar login pagina
                current_url = page.url

                if "login" in current_url.lower() or "oidc" in current_url.lower():
                    logger.error(f"  ✗ Doorgestuurd naar login pagina - sessie ongeldig (URL: {current_url})")
                    browser.close()
                    return False

                browser.close()

                if error_responses:
                    logger.error(f"✗ Sessie is niet geldig ({len(error_responses)} auth errors)")
                    return False
                elif afspraken_response:
                    logger.info("✓ Sessie is nog geldig")
                    return True
                else:
                    # Probeer API call om te valideren
                    logger.info("  Geen afspraken response, probeer directe API test...")
                    return self.test_session_api()

        except Exception as e:
            logger.error(f"⚠ Fout bij testen sessie: {e}", exc_info=True)
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
                    logger.info("✓ Sessie is geldig (via API)")
                    return True
                else:
                    logger.error(f"✗ API test mislukt: status {result.get('status')}")
                    return False

        except Exception as e:
            logger.error(f"✗ API test error: {e}", exc_info=True)
            return False

    def fetch_afspraken(self, days=7, persoon_id=None):
        """Haal afspraken op met Playwright voor een bepaald aantal dagen en specifiek persoon"""
        if not self.session_exists():
            logger.error("✗ Geen sessie gevonden")
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
                    logger.debug(f"  Direct API call naar /api/personen/{persoon_id}/afspraken")

                    # Eerst een pagina laden om cookies/sessie te initialiseren
                    page.goto(f"{MAGISTER_URL}/magister/", wait_until="networkidle")
                    page.wait_for_timeout(1000)

                    # Nu direct API call doen via fetch in de browser context
                    # Haal ALLE statussen op (1=gepland, 2=gewijzigd, 3=vervallen, 5=verplaatst, etc)
                    api_url = f"{MAGISTER_URL}/api/personen/{persoon_id}/afspraken?tot={tot_datum}&van={van_datum}"
                    logger.debug(f"  API URL: {api_url}")

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

                        # schrijf debug output
                        with open("/tmp/debug.json", "w", encoding="utf-8") as f:
                            json.dump(result, f, indent=2, ensure_ascii=False)

                        if result and 'Items' in result:
                            logger.info(f"✓ Afspraken opgehaald via API: {len(result.get('Items', []))} items ({van_datum} t/m {tot_datum})")
                            return result
                        else:
                            logger.error("✗ Geen items in API response")
                            return None

                    except Exception as api_error:
                        logger.error(f"✗ API call mislukt: {api_error}", exc_info=True)
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
                        logger.error("✗ Geen /afspraken response gevonden")
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

                    logger.info(f"✓ Afspraken opgehaald: {len(combined_data.get('Items', []))} items ({van_datum} t/m {tot_datum})")
                    return combined_data

        except Exception as e:
            logger.error(f"✗ Fout bij ophalen afspraken: {e}", exc_info=True)
            return None

    def export_to_ical(self, appointments, output_file=ICAL_FILE):
        """Exporteer afspraken naar iCal formaat"""
        if not appointments or 'Items' not in appointments:
            logger.error("✗ Geen afspraken om te exporteren")
            return False

        try:
            cal = Calendar()

            for item in appointments['Items']:
                e = Event()

                # Check status en voeg prefix toe
                status = item.get("Status", 1)
                status_prefix = ""

                if status == 3:
                    status_prefix = "[UITGEVALLEN] "
                elif status == 5:
                    status_prefix = "[VERPLAATST] "
                elif status == 2:
                    status_prefix = "[GEWIJZIGD] "

                # Titel: vakken + omschrijving
                vakken = ", ".join(v["Naam"] for v in item.get("Vakken", []))
                titel = item.get("Omschrijving", "Geen titel")
                if vakken:
                    titel = f"{vakken} – {titel}"

                # Voeg status prefix toe
                e.name = f"{status_prefix}{titel}"
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

            logger.info(f"✓ iCal bestand bijgewerkt: {output_file} ({len(cal.events)} afspraken)")
            return True

        except Exception as e:
            logger.error(f"✗ Fout bij exporteren naar iCal: {e}", exc_info=True)
            return False


def main():
    """Hoofdfunctie voor server"""
    logger.info("="*70)
    logger.info("MAGISTER SERVER - HEADLESS MODE (MULTI-KIND) - DEV VERSION")
    logger.info(f"Log file: {LOG_FILE}")
    logger.info(f"Output directory: {OUTPUT_DIR}")
    logger.info("="*70)

    # Zorg dat OUTPUT_DIR bestaat
    try:
        Path(OUTPUT_DIR).mkdir(parents=True, exist_ok=True)
        logger.info(f"✓ Output directory gereed: {OUTPUT_DIR}")
    except Exception as e:
        logger.error(f"✗ Kan output directory niet aanmaken: {e}")
        import sys
        sys.exit(1)

    client = MagisterServerClient()

    # Check of sessie bestaat
    if not client.session_exists():
        logger.error(f"✗ Geen sessie gevonden: {SESSION_FILE}")
        logger.info("Voer de volgende stappen uit:")
        logger.info("1. Draai magister_login.py op je laptop")
        logger.info(f"2. Kopieer {SESSION_FILE} naar deze server")
        logger.info("3. Start dit script opnieuw")
        import sys
        sys.exit(1)  # Exit met code 1 = sessie probleem

    logger.info(f"✓ Sessie bestand gevonden: {SESSION_FILE}")

    # Test sessie
    if not client.test_session():
        logger.error("✗ Sessie is niet meer geldig!")
        logger.info("De sessie is verlopen. Voer de volgende stappen uit:")
        logger.info("1. Draai magister_login.py op je laptop (opnieuw inloggen)")
        logger.info(f"2. Kopieer het nieuwe {SESSION_FILE} naar deze server")
        logger.info("3. Start dit script opnieuw")
        import sys
        sys.exit(1)  # Exit met code 1 = sessie probleem

    # Haal lijst van kinderen op
    logger.info("=== Kinderen detecteren ===")
    kinderen = client.fetch_kinderen()

    if not kinderen:
        logger.warning("⚠ Geen kinderen gevonden, gebruik standaard methode")
        # Fallback naar oude methode
        appointments = client.fetch_afspraken(days=7)
        if appointments:
            client.export_to_ical(appointments)
        return

    # Haal voor elk kind de agenda op
    logger.info("=== Agenda's ophalen ===")
    kind_data = {}

    for kind in kinderen:
        naam = kind['Roepnaam']
        persoon_id = kind['Id']

        logger.info(f"→ {naam} (ID: {persoon_id})...")
        appointments = client.fetch_afspraken(days=7, persoon_id=persoon_id)

        if appointments:
            # Maak bestandsnaam: magister_<naam>.ics in OUTPUT_DIR
            output_file = str(Path(OUTPUT_DIR) / f"magister_{naam.lower()}.ics")
            client.export_to_ical(appointments, output_file)
            kind_data[naam] = {
                'id': persoon_id,
                'file': output_file
            }
        else:
            logger.warning(f"  ⚠ Kon agenda voor {naam} niet ophalen")

    if not kind_data:
        logger.error("✗ Kon geen agenda's ophalen voor kinderen")
        return

    # Genereer index.html met lijst van calendars
    logger.info("=== Index genereren ===")
    generate_index_html()

    # Keep-alive loop
    logger.info(f"=== Keep-alive gestart (elke {KEEP_ALIVE_INTERVAL//60} minuten) ===")
    logger.info(f"Het script update {len(kind_data)} agenda bestand(en) automatisch")
    logger.info("Druk op Ctrl+C om te stoppen")

    try:
        while True:
            time.sleep(KEEP_ALIVE_INTERVAL)

            logger.info(f"Keep-alive: agenda's ophalen...")

            # Update elk kind
            for naam, info in kind_data.items():
                logger.info(f"  → {naam}...")
                appointments = client.fetch_afspraken(days=7, persoon_id=info['id'])

                if appointments:
                    client.export_to_ical(appointments, info['file'])
                else:
                    logger.warning(f"  ⚠ Kon agenda voor {naam} niet ophalen")

            # Update index.html na het updaten van alle calendars
            logger.info("  → index.html...")
            generate_index_html()

    except KeyboardInterrupt:
        logger.info("✓ Server gestopt door gebruiker")


if __name__ == "__main__":
    main()
