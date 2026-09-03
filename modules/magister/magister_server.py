#!/usr/bin/env python3
"""
Magister Server Script - Voor op je SERVER (headless)
Dit script draait zonder GUI en gebruikt alleen magister_session.json
"""

import time
import random
import os
import glob
import re
import json
import subprocess
import logging
from pathlib import Path
from datetime import datetime, timedelta, timezone
import urllib.request
import urllib.parse
import urllib.error
from dateutil import parser
from bs4 import BeautifulSoup
from email.message import EmailMessage


# Configuratie
MAGISTER_URL = "https://groevenbeek.magister.net"
SESSION_FILE = "magister_session.json"  # legacy (cookie-scrape), niet meer gebruikt
TOKEN_FILE = "token.json"               # refresh/access-token state (mode 0600)
ICAL_FILE = "magister.ics"
KEEP_ALIVE_INTERVAL = 30 * 60   # basis-interval keep-alive (30 min)
KEEP_ALIVE_JITTER = 5 * 60      # ± jitter (max 5 min): niet exact op de klok
WINDOW_START_HOUR = 7           # alleen ophalen vanaf 07:00 ...
WINDOW_END_HOUR = 22            # ... tot 22:00 (laatste run rond 21:59); 's nachts stil

# OAuth via de mobiele-app-client (M6LOAPP): stille refresh, geen ~10u SSO-cliff meer.
AUTHORITY = "https://accounts.magister.net"
TOKEN_URL = f"{AUTHORITY}/connect/token"
OAUTH_CLIENT_ID = "M6LOAPP"

# Realistische app-User-Agent zodat de calls niet als 'Python-urllib/x.y' opvallen
# in Magisters logs, maar op app-verkeer lijken.
MAGISTER_UA = "Magister/main.ioAppStore (iPhone; iOS)"


class SessionInvalid(Exception):
    """Refresh-token definitief ongeldig (invalid_grant): opnieuw inloggen vereist."""
LOG_FILE = "/var/log/magister/magister.log"
ERROR_EMAIL = "wvdtoorren@gmail.com"
HEARTBEAT_FILE = "/var/lib/prometheus-node-exporter-textfiles/magister_heartbeat.prom"

# Logging configuratie
def setup_logging():
    """Setup logging naar file en console"""
    global LOG_FILE

    log_dir = Path(LOG_FILE).parent

    # Probeer log directory aan te maken als het niet bestaat
    try:
        log_dir.mkdir(parents=True, exist_ok=True)
    except (PermissionError, OSError):
        # Fallback naar local directory als we geen rechten hebben
        LOG_FILE = "./magister.log"
        logger.warning(f"⚠ Geen write permissie voor /var/log/magister, gebruik {LOG_FILE}")

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


def send_error_email(subject, body):
    """Stuur een error email via postfix/sendmail"""
    try:
        msg = EmailMessage()
        msg['Subject'] = f"[Magister Sync] {subject}"
        msg['From'] = f"magister@{os.uname().nodename}"
        msg['To'] = ERROR_EMAIL
        msg.set_content(body)

        # Gebruik sendmail (NixOS wrapper)
        sendmail_process = subprocess.Popen(
            ['/run/wrappers/bin/sendmail', '-t', '-oi'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

        stdout, stderr = sendmail_process.communicate(msg.as_string())

        if sendmail_process.returncode == 0:
            logger.info(f"✓ Error email verzonden naar {ERROR_EMAIL}")
            return True
        else:
            logger.error(f"✗ Kon email niet verzenden: {stderr}")
            return False

    except Exception as e:
        logger.error(f"✗ Fout bij verzenden email: {e}", exc_info=True)
        return False


def write_heartbeat():
    """Schrijf heartbeat metric voor Prometheus monitoring"""
    try:
        timestamp = time.time()
        with open(HEARTBEAT_FILE + ".tmp", "w") as f:
            f.write(f"# HELP magister_sync_heartbeat_timestamp Unix timestamp van laatste heartbeat\n")
            f.write(f"# TYPE magister_sync_heartbeat_timestamp gauge\n")
            f.write(f"magister_sync_heartbeat_timestamp {timestamp}\n")

        # Atomic rename
        os.rename(HEARTBEAT_FILE + ".tmp", HEARTBEAT_FILE)
        logger.debug(f"Heartbeat geschreven: {timestamp}")
        return True
    except Exception as e:
        logger.warning(f"Kon heartbeat niet schrijven: {e}")
        return False


def send_success_email(kinderen_count, calendars):
    """Stuur een succes notificatie email bij succesvolle start"""
    try:
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

        body = f"De Magister synchronisatie service is succesvol gestart!\n\n"
        body += f"Server: {os.uname().nodename}\n"
        body += f"Tijdstip: {timestamp}\n"
        body += f"Aantal kinderen: {kinderen_count}\n\n"
        body += "Agenda's beschikbaar:\n"

        for naam, info in calendars.items():
            body += f"  - {naam}: {info['file']}\n"

        body += f"\nDe agenda's worden automatisch bijgewerkt elke {KEEP_ALIVE_INTERVAL//60} minuten.\n"
        body += "\nBekijk de agenda's op: https://agenda.toorren.net/\n"

        msg = EmailMessage()
        msg['Subject'] = f"[Magister Sync] Service gestart"
        msg['From'] = f"magister@{os.uname().nodename}"
        msg['To'] = ERROR_EMAIL
        msg.set_content(body)

        # Gebruik sendmail (NixOS wrapper)
        sendmail_process = subprocess.Popen(
            ['/run/wrappers/bin/sendmail', '-t', '-oi'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

        stdout, stderr = sendmail_process.communicate(msg.as_string())

        if sendmail_process.returncode == 0:
            logger.info(f"✓ Succes notificatie verzonden naar {ERROR_EMAIL}")
            return True
        else:
            logger.error(f"✗ Kon succes email niet verzenden: {stderr}")
            return False

    except Exception as e:
        logger.error(f"✗ Fout bij verzenden succes email: {e}", exc_info=True)
        return False


def generate_index_html(domain="agenda.toorren.net"):
    """Genereer index.html met lijst van beschikbare calendars"""
    try:
        # Zoek alle magister_*.ics bestanden
        ics_files = sorted(Path(".").glob("magister_*.ics"))

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
    <p><strong>Updates:</strong> elke ~{KEEP_ALIVE_INTERVAL//60} min ({WINDOW_START_HOUR:02d}:00-{WINDOW_END_HOUR:02d}:00u)</p>
    <p><strong>Laatste update:</strong> {update_timestamp}</p>
  </div>
</body>
</html>
"""

        # Schrijf naar bestand
        with open("index.html", "w") as f:
            f.write(html)

        logger.info(f"✓ index.html gegenereerd met {len(ics_files)} calendar(s)")
        return True

    except Exception as e:
        logger.error(f"✗ Fout bij genereren index.html: {e}", exc_info=True)
        return False


class MagisterServerClient:
    def __init__(self):
        self.token_file = Path(TOKEN_FILE)
        self.afspraken_data = None
        self.kinderen = []
        self.account_person_id = None
        self._tokens = None

    def session_exists(self):
        """Check of er een token-bestand (refresh-token) bestaat"""
        return self.token_file.exists()

    # ── Token-beheer (refresh-token flow; het refresh-token ROTEERT) ─────────
    def _load_tokens(self):
        if self._tokens is None:
            with open(self.token_file, encoding="utf-8") as f:
                self._tokens = json.load(f)
        return self._tokens

    def _save_tokens(self, tok):
        self._tokens = tok
        tmp = str(self.token_file) + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(tok, f, indent=2)
        os.chmod(tmp, 0o600)
        os.replace(tmp, self.token_file)  # atomair

    def _refresh_access_token(self):
        tok = self._load_tokens()
        refresh = tok.get("refresh_token")
        if not refresh:
            raise SessionInvalid("geen refresh_token in token.json")

        data = urllib.parse.urlencode({
            "grant_type": "refresh_token",
            "refresh_token": refresh,
            "client_id": OAUTH_CLIENT_ID,
        }).encode("ascii")
        req = urllib.request.Request(
            TOKEN_URL, data=data,
            headers={
                "Content-Type": "application/x-www-form-urlencoded",
                "User-Agent": MAGISTER_UA,
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                new = json.loads(r.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", "replace")
            if e.code in (400, 401) and "invalid_grant" in body:
                raise SessionInvalid(f"refresh geweigerd (invalid_grant): {body}")
            raise  # 5xx/tijdelijk (bv. Magister-onderhoud): caller behandelt als transient

        merged = dict(tok)
        # ROTATIE: bewaar het NIEUWE refresh-token; het oude vervalt hierna.
        merged["refresh_token"] = new.get("refresh_token", refresh)
        merged["access_token"] = new["access_token"]
        merged["access_expires"] = time.time() + int(new.get("expires_in", 3600)) - 60
        self._save_tokens(merged)
        logger.info("✓ Access-token vernieuwd (refresh-token geroteerd)")
        return merged["access_token"]

    def get_access_token(self):
        """Geef een geldige access-token; ververs via refresh indien (bijna) verlopen."""
        tok = self._load_tokens()
        access = tok.get("access_token")
        if access and time.time() < tok.get("access_expires", 0):
            return access
        return self._refresh_access_token()

    def api_get(self, path):
        """GET op de tenant-API met Bearer-token; 1x retry na geforceerde refresh bij 401."""
        access = self.get_access_token()

        def _do(token):
            req = urllib.request.Request(
                MAGISTER_URL + path,
                headers={
                    "Authorization": f"Bearer {token}",
                    "Accept": "application/json",
                    "User-Agent": MAGISTER_UA,
                },
            )
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.loads(r.read().decode("utf-8"))

        try:
            return _do(access)
        except urllib.error.HTTPError as e:
            if e.code == 401:
                logger.warning(f"  API {path} gaf 401; forceer refresh en retry")
                return _do(self._refresh_access_token())
            raise

    def fetch_kinderen(self):
        """Haal lijst van kinderen op van het ouderaccount (Bearer-API)"""
        try:
            acc = self.api_get("/api/account")
        except SessionInvalid:
            raise
        except Exception as e:
            logger.error(f"✗ Kon /api/account niet ophalen: {e}", exc_info=True)
            return None

        person_id = acc.get("Id") or (acc.get("Persoon") or {}).get("Id")
        if not person_id:
            logger.error("✗ Geen person-id in /api/account response")
            return None
        self.account_person_id = person_id

        try:
            data = self.api_get(f"/api/personen/{person_id}/kinderen")
        except urllib.error.HTTPError as e:
            if e.code == 404:
                # Geen kinderen-endpoint -> account is zelf de leerling.
                logger.info("Geen kinderen-endpoint (404): account is zelf de leerling")
                roep = (acc.get("Persoon") or {}).get("Roepnaam") or "agenda"
                self.kinderen = [{"Id": person_id, "Roepnaam": roep, "Stamnummer": None}]
                return self.kinderen
            logger.error(f"✗ Kon kinderen niet ophalen: HTTP {e.code}", exc_info=True)
            return None
        except Exception as e:
            logger.error(f"✗ Fout bij ophalen kinderen: {e}", exc_info=True)
            return None

        self.kinderen = data.get("Items", [])
        if self.kinderen:
            logger.info(f"✓ Gevonden: {len(self.kinderen)} kind(eren)")
            for kind in self.kinderen:
                logger.info(f"  - {kind.get('Roepnaam')} (ID: {kind.get('Id')}, Stamnr: {kind.get('Stamnummer')})")
            return self.kinderen
        logger.warning("⚠ Geen kinderen gevonden")
        return None

    def test_session(self):
        """Sessie geldig = kunnen we (indien nodig) verversen?

        Bepaalt of we FATAAL stoppen. Een 5xx/netwerkfout (bv. Magister-onderhoud)
        is NIET fataal; alleen een invalid_grant (refresh-token dood) wel.
        """
        if not self.session_exists():
            return False
        try:
            logger.info("Testen van sessie (refresh-token)...")
            self.get_access_token()  # ververst indien nodig; SessionInvalid als refresh dood is
            logger.info("✓ Sessie is geldig (refresh werkt)")
            return True
        except SessionInvalid as e:
            logger.error(f"  ✗ Refresh-token ongeldig: {e}")
            return False
        except Exception as e:
            logger.warning(f"  ⚠ Tijdelijke fout bij sessietest ({e}); sessie als geldig beschouwd")
            return True

    def fetch_afspraken(self, days=21, persoon_id=None):
        """Haal afspraken op via de Bearer-API voor een kind (of het account zelf)."""
        if persoon_id is None:
            persoon_id = self.account_person_id
        if not persoon_id:
            logger.error("✗ Geen persoon_id voor afspraken")
            return None

        # Bereken start (maandag) en eind van de periode
        today = datetime.now()
        start_of_week = today - timedelta(days=today.weekday())  # Maandag
        end_of_week = start_of_week + timedelta(days=days - 1)
        van_datum = start_of_week.strftime('%Y-%m-%d')
        tot_datum = end_of_week.strftime('%Y-%m-%d')

        # Haal ALLE statussen op (1=gepland, 2=gewijzigd, 3=vervallen, 5=verplaatst, etc)
        path = f"/api/personen/{persoon_id}/afspraken?tot={tot_datum}&van={van_datum}"
        try:
            result = self.api_get(path)
        except Exception as e:
            logger.error(f"✗ API call mislukt voor persoon {persoon_id}: {e}", exc_info=True)
            return None

        # Debug-output (zelfde pad als voorheen)
        try:
            with open("/tmp/debug.json", "w", encoding="utf-8") as f:
                json.dump(result, f, indent=2, ensure_ascii=False)
        except OSError:
            pass

        if result and 'Items' in result:
            logger.info(f"✓ Afspraken opgehaald via API: {len(result.get('Items', []))} items ({van_datum} t/m {tot_datum})")
            return result
        logger.error("✗ Geen items in API response")
        return None

    def ical_escape(self, text):
        """
        Escape text for iCalendar format according to RFC5545.
        - Escape backslashes first (to avoid double-escaping)
        - Escape semicolons and commas
        - Replace newlines with \\n (literal backslash-n)
        """
        if not text:
            return ""

        # Order matters: backslash first to avoid double-escaping
        text = str(text).replace("\\", "\\\\")  # Backslash -> \\
        text = text.replace(";", "\\;")          # Semicolon -> \;
        text = text.replace(",", "\\,")          # Comma -> \,
        text = text.replace("\r\n", "\\n")       # CRLF -> \n
        text = text.replace("\n", "\\n")         # LF -> \n
        text = text.replace("\r", "\\n")         # CR -> \n

        return text

    def fold_ical_line(self, line):
        """
        Fold iCalendar lines according to RFC5545:
        - Lines should not exceed 75 octets
        - Folding is done by inserting CRLF followed by a single space
        """
        if len(line) <= 75:
            return line

        folded = []
        start = 0

        # First line can be 75 chars
        folded.append(line[start:75])
        start = 75

        # Subsequent lines can be 74 chars (account for leading space)
        while start < len(line):
            folded.append(" " + line[start:start + 74])
            start += 74

        return "\r\n".join(folded)

    def export_to_ical(self, appointments, output_file=ICAL_FILE):
        """Exporteer afspraken naar iCal formaat met RFC5545 compliance"""
        if not appointments or 'Items' not in appointments:
            logger.error("✗ Geen afspraken om te exporteren")
            return False

        try:
            lines = []

            # Calendar header
            lines.append("BEGIN:VCALENDAR")
            lines.append("VERSION:2.0")
            lines.append("PRODID:-//Magister//Agenda Sync//NL")
            lines.append("CALSCALE:GREGORIAN")
            lines.append("METHOD:PUBLISH")

            for item in appointments['Items']:
                # Check status en voeg prefix toe
                status = item.get("Status", 1)
                status_prefix = ""
                transparent = False  # TRANSP:TRANSPARENT = tijd geldt als vrij/beschikbaar

                if status == 5:
                    # [VERPLAATST]: leeg "spook" op het OUDE lesuur. De echte les draait
                    # als gewone afspraak (Status 1) op zijn nieuwe uur, dus dit item
                    # helemaal overslaan voorkomt een fantoom-duplicaat in de agenda.
                    continue
                elif status == 3:
                    status_prefix = "[KEUZE] "
                    transparent = True  # les gaat niet door -> blok als beschikbaar tonen
                elif status == 2:
                    status_prefix = "[GEWIJZIGD] "

                # InfoType = soort inhoud in Magister (het "icoontje" bij een les).
                # We spiegelen dit: 📚 huiswerk, 📝 toetsen/overhoringen, ℹ️ info.
                info_type = item.get("InfoType", 0)
                info_emoji, info_label = {
                    1: ("📚", "Huiswerk"),
                    2: ("📝", "Proefwerk"),
                    3: ("📝", "Tentamen"),
                    4: ("📝", "SO"),
                    5: ("📝", "Mondeling"),
                    6: ("ℹ️", "Informatie"),
                }.get(info_type, ("", ""))

                # Titel: vakken + omschrijving
                vakken = ", ".join(v["Naam"] for v in item.get("Vakken", []))
                titel = item.get("Omschrijving", "Geen titel")
                if vakken:
                    titel = f"{vakken} – {titel}"

                # Voeg status prefix + info-emoji (huiswerk/toets) toe
                summary = f"{status_prefix}{titel}"
                if info_emoji:
                    summary = f"{summary} {info_emoji}"

                # Parse dates. Magister levert UTC ("...Z"). Normaliseer robuust
                # naar UTC zodat we hieronder met een expliciete "Z" wegschrijven.
                # Zonder Z/TZID is een DATE-TIME "floating" en interpreteert Google
                # Calendar hem als LOKALE tijd -> events staan dan 1-2u verkeerd (DST).
                dt_start = parser.isoparse(item["Start"])
                dt_end = parser.isoparse(item["Einde"])
                if dt_start.tzinfo is None:
                    dt_start = dt_start.replace(tzinfo=timezone.utc)
                if dt_end.tzinfo is None:
                    dt_end = dt_end.replace(tzinfo=timezone.utc)
                dt_start = dt_start.astimezone(timezone.utc)
                dt_end = dt_end.astimezone(timezone.utc)

                # DTSTAMP in UTC (now)
                dtstamp = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")

                # Locatie
                lokalen = ", ".join(l["Naam"] for l in item.get("Lokalen", []))
                location = lokalen or item.get("Lokatie", "")

                # Beschrijving
                beschrijving = []
                if item.get("Docenten"):
                    docenten = ", ".join(d["Naam"] for d in item["Docenten"])
                    beschrijving.append(f"Docent(en): {docenten}")

                if item.get("Inhoud"):
                    # Zet paragraaf-/regeleindes om naar newlines vóór het strippen,
                    # anders plakken <p>-blokken aan elkaar ("...1205" + "3e uur..." ->
                    # "12053e uur"). Inline tekst blijft wel intact.
                    html = re.sub(r"</p>|<br\s*/?>", "\n", item["Inhoud"], flags=re.I)
                    soup = BeautifulSoup(html, "html.parser")
                    inhoud_txt = re.sub(r"\n{3,}", "\n\n", soup.get_text()).strip()
                    if inhoud_txt:
                        # Label de inhoud met het soort (Huiswerk/Proefwerk/...) als
                        # InfoType dat aangeeft; anders gewoon de tekst.
                        if info_label:
                            block = f"{info_emoji} {info_label}:\n{inhoud_txt}"
                        else:
                            block = inhoud_txt
                        # Blanco regel tussen docenten en de inhoud
                        beschrijving.append(("\n" + block) if beschrijving else block)

                description = "\n".join(beschrijving)

                # UID
                uid = f"magister-{item['Id']}@groevenbeek"

                # Build event
                lines.append("BEGIN:VEVENT")
                lines.append(self.fold_ical_line(f"UID:{self.ical_escape(uid)}"))
                lines.append(self.fold_ical_line(f"DTSTAMP:{dtstamp}"))
                lines.append(self.fold_ical_line(f"DTSTART:{dt_start.strftime('%Y%m%dT%H%M%S')}Z"))
                lines.append(self.fold_ical_line(f"DTEND:{dt_end.strftime('%Y%m%dT%H%M%S')}Z"))
                lines.append(self.fold_ical_line(f"SUMMARY:{self.ical_escape(summary)}"))

                if description:
                    lines.append(self.fold_ical_line(f"DESCRIPTION:{self.ical_escape(description)}"))

                if location:
                    lines.append(self.fold_ical_line(f"LOCATION:{self.ical_escape(location)}"))

                # Uitgevallen les: markeer als vrij/beschikbaar (event blijft zichtbaar
                # met [UITGEVALLEN]-label, maar bezet je tijd niet in free/busy).
                if transparent:
                    lines.append("TRANSP:TRANSPARENT")

                lines.append("END:VEVENT")

            lines.append("END:VCALENDAR")

            # Write to file with CRLF line endings
            with open(output_file, "w", encoding="utf-8") as f:
                f.write("\r\n".join(lines) + "\r\n")

            logger.info(f"✓ iCal bestand bijgewerkt: {output_file} ({len(appointments['Items'])} afspraken)")
            return True

        except Exception as e:
            logger.error(f"✗ Fout bij exporteren naar iCal: {e}", exc_info=True)
            return False


def main():
    """Hoofdfunctie voor server"""
    logger.info("="*70)
    logger.info("MAGISTER SERVER - HEADLESS MODE (MULTI-KIND)")
    logger.info(f"Log file: {LOG_FILE}")
    logger.info("="*70)

    client = MagisterServerClient()

    # Check of token-bestand bestaat
    if not client.session_exists():
        error_msg = f"Geen token gevonden: {TOKEN_FILE}\n\n"
        error_msg += "Voer de volgende stappen uit:\n"
        error_msg += "1. Draai verify_pkce.py op je laptop (login met passkey)\n"
        error_msg += f"2. Zet het refresh_token in {client.token_file} op deze server (mode 0600)\n"
        error_msg += "3. Start dit script opnieuw\n"

        logger.error(f"✗ {error_msg}")

        send_error_email(
            subject="Token bestand niet gevonden",
            body=error_msg
        )

        import sys
        sys.exit(1)  # Exit met code 1 = token probleem

    logger.info(f"✓ Token-bestand gevonden: {TOKEN_FILE}")

    # Test sessie (kunnen we verversen?)
    if not client.test_session():
        error_msg = "Refresh-token is ongeldig geworden!\n\n"
        error_msg += "Opnieuw inloggen vereist. Voer de volgende stappen uit:\n"
        error_msg += "1. Draai verify_pkce.py op je laptop (login met passkey)\n"
        error_msg += f"2. Zet het nieuwe refresh_token in {client.token_file} (mode 0600)\n"
        error_msg += "3. Start dit script opnieuw\n\n"
        error_msg += f"Server: {os.uname().nodename}\n"
        error_msg += f"Tijdstip: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"

        logger.error(f"✗ {error_msg}")

        send_error_email(
            subject="Refresh-token ongeldig - opnieuw inloggen vereist",
            body=error_msg
        )

        import sys
        sys.exit(1)  # Exit met code 1 = token probleem

    # Haal lijst van kinderen op
    logger.info("=== Kinderen detecteren ===")
    kinderen = client.fetch_kinderen()

    if not kinderen:
        logger.warning("⚠ Geen kinderen gevonden, gebruik standaard methode")
        # Fallback naar oude methode
        appointments = client.fetch_afspraken(days=21)
        if appointments:
            client.export_to_ical(appointments)
        return

    # Haal voor elk kind de agenda op
    logger.info("\n=== Agenda's ophalen ===")
    kind_data = {}

    for kind in kinderen:
        naam = kind['Roepnaam']
        persoon_id = kind['Id']

        logger.info(f"\n→ {naam} (ID: {persoon_id})...")
        appointments = client.fetch_afspraken(days=21, persoon_id=persoon_id)

        if appointments:
            # Maak bestandsnaam: magister_<naam>.ics
            output_file = f"magister_{naam.lower()}.ics"
            client.export_to_ical(appointments, output_file)
            kind_data[naam] = {
                'id': persoon_id,
                'file': output_file
            }
        else:
            logger.info(f"  ⚠ Kon agenda voor {naam} niet ophalen")

    if not kind_data:
        logger.info("\n✗ Kon geen agenda's ophalen voor kinderen")
        return

    # Ruim verweesde agenda's op: verwijder magister_*.ics van kinderen die niet
    # meer in het account zitten (bv. school verlaten). Zonder dit blijft een oude,
    # verouderde feed voor altijd gepubliceerd staan. Baseer op de kinderen-roster
    # (niet kind_data), zodat een transient mislukte fetch geen bestand wist.
    huidige_bestanden = {f"magister_{k['Roepnaam'].lower()}.ics" for k in kinderen}
    for oud in glob.glob("magister_*.ics"):
        if os.path.basename(oud) not in huidige_bestanden:
            try:
                os.remove(oud)
                logger.info(f"🗑  Verweesde agenda verwijderd: {oud}")
            except OSError as e:
                logger.warning(f"⚠ Kon verweesde agenda {oud} niet verwijderen: {e}")

    # Genereer index.html met lijst van calendars
    logger.info("\n=== Index genereren ===")
    generate_index_html()

    # Stuur succes notificatie email
    logger.info("\n=== Succes notificatie ===")
    send_success_email(len(kinderen), kind_data)

    # Schrijf initiële heartbeat
    write_heartbeat()

    # Keep-alive loop
    logger.info(f"\n=== Keep-alive gestart (~{KEEP_ALIVE_INTERVAL//60} min ±{KEEP_ALIVE_JITTER//60}, venster {WINDOW_START_HOUR:02d}:00-{WINDOW_END_HOUR:02d}:00u) ===")
    logger.info(f"Het script update {len(kind_data)} agenda bestand(en) automatisch")
    logger.info("Druk op Ctrl+C om te stoppen\n")

    failed_updates = 0  # Teller voor mislukte updates
    max_failed_updates = 3  # Aantal mislukte updates voordat we sessie testen

    def _in_window(dt):
        return WINDOW_START_HOUR <= dt.hour < WINDOW_END_HOUR

    try:
        while True:
            now = datetime.now()
            if _in_window(now):
                # Binnen het venster: jittered interval slapen, dan ophalen.
                sleep_s = max(60, KEEP_ALIVE_INTERVAL + random.uniform(-KEEP_ALIVE_JITTER, KEEP_ALIVE_JITTER))
                time.sleep(sleep_s)
                if not _in_window(datetime.now()):
                    continue  # tijdens de slaap het venster uitgelopen -> herbereken bovenaan
            else:
                # Buiten het venster: slaap tot de volgende 06:00 en haal dan meteen op.
                target = now.replace(hour=WINDOW_START_HOUR, minute=0, second=0, microsecond=0)
                if now.hour >= WINDOW_START_HOUR:
                    target += timedelta(days=1)
                wait_s = (target - now).total_seconds()
                logger.info(f"[{now:%H:%M}] Buiten venster {WINDOW_START_HOUR:02d}:00-{WINDOW_END_HOUR:02d}:00u; slaap {wait_s/3600:.1f}u")
                time.sleep(wait_s)

            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            logger.info(f"\n[{timestamp}] Keep-alive: agenda's ophalen...")

            # Update elk kind
            update_success = False
            for naam, info in kind_data.items():
                logger.info(f"  → {naam}...")
                appointments = client.fetch_afspraken(days=21, persoon_id=info['id'])

                if appointments:
                    client.export_to_ical(appointments, info['file'])
                    update_success = True
                else:
                    logger.warning(f"  ⚠ Kon agenda voor {naam} niet ophalen")

            # Check of er updates zijn gelukt
            if not update_success:
                failed_updates += 1
                logger.warning(f"  ⚠ Geen agenda's konden worden opgehaald ({failed_updates}/{max_failed_updates})")

                # Na 3 mislukte updates, test of sessie nog geldig is
                if failed_updates >= max_failed_updates:
                    logger.warning("  → Testen van sessie...")
                    if not client.test_session():
                        error_msg = "Refresh-token is ongeldig geworden tijdens runtime!\n\n"
                        error_msg += "De sessie is verlopen tijdens het draaien van de service.\n"
                        error_msg += "Voer de volgende stappen uit:\n"
                        error_msg += "1. Draai verify_pkce.py op je laptop (login met passkey)\n"
                        error_msg += f"2. Zet het nieuwe refresh_token in {TOKEN_FILE} op deze server\n"
                        error_msg += "3. Herstart de magister-sync service\n\n"
                        error_msg += f"Server: {os.uname().nodename}\n"
                        error_msg += f"Tijdstip: {timestamp}\n"

                        logger.error(f"✗ {error_msg}")

                        # Stuur email
                        send_error_email(
                            subject="Sessie ongeldig - service gestopt",
                            body=error_msg
                        )

                        import sys
                        sys.exit(1)  # Stop service, NixOS zal NIET herstarten (RestartPreventExitStatus=1)
                    else:
                        logger.info("  ✓ Sessie is nog geldig, mogelijk tijdelijk probleem")
                        failed_updates = 0  # Reset teller
            else:
                # Reset teller bij succesvolle update
                failed_updates = 0

            # Update index.html na het updaten van alle calendars
            logger.info("  → index.html...")
            generate_index_html()

            # Update heartbeat
            write_heartbeat()

    except KeyboardInterrupt:
        logger.info("\n\n✓ Server gestopt door gebruiker")


if __name__ == "__main__":
    main()
