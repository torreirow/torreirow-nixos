#!/usr/bin/env python3
"""Houd de AI-crawler-blokkade van nginx actueel.

Haalt de botlijst van ai-robots-txt/ai.robots.txt op en schrijft:
  - ai-bots-map.conf   map $http_user_agent $ai_bot (op http-niveau geïncludeerd)
  - robots/<vhost>.txt per site: de bestaande robots.txt uit de webroot als basis,
                       aangevuld met een Disallow-groep voor elke AI-bot die daar
                       nog niet in staat (bestaande regels blijven ongemoeid).

Veiligheid: minder dan MIN_BOTS bots of een netwerkfout laat de map ongewijzigd
(de robots-bestanden worden dan uit de laatst bekende lijst opgebouwd). Bestanden
worden atomisch geschreven; na een gewijzigde map volgt nginx -t, bij falen gaat de
vorige versie terug (exit 1), bij succes een reload.

Omgeving:
  STATE_DIR   uitvoermap (bijv. /var/lib/ai-blocklist)
  SITES_JSON  pad naar JSON-lijst {vhost, webroot, sitemap, noindex, allowAgents} (uit Nix)
"""
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.request

SOURCE_URL = "https://raw.githubusercontent.com/ai-robots-txt/ai.robots.txt/main/robots.json"
MIN_BOTS = 50

# Applebot is de gewone Apple-zoekcrawler; Applebot-Extended (AI-training) blijft geblokkeerd.
ALLOWLIST = {"Applebot"}
EXTRA_BLOCK = set()

STATE_DIR = os.environ.get("STATE_DIR", "/var/lib/ai-blocklist")
MAP_FILE = os.path.join(STATE_DIR, "ai-bots-map.conf")
CACHE_FILE = os.path.join(STATE_DIR, "robots.json")
ROBOTS_DIR = os.path.join(STATE_DIR, "robots")


def log(msg):
    print(msg, flush=True)


def fetch_bots():
    req = urllib.request.Request(SOURCE_URL, headers={"User-Agent": "ai-blocklist-updater"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = json.load(resp)
    if not isinstance(data, dict):
        raise ValueError("robots.json is geen object")
    return data


def bot_names(data):
    # robots.txt en de map zijn hoofdletterongevoelig: ontdubbel op kleine letters
    # (de lijst bevat o.a. Webzio-Extended én webzio-extended) met een vaste volgorde,
    # anders verschilt de uitvoer per run door hash-randomisatie.
    names = sorted({str(k).strip() for k in data} | EXTRA_BLOCK, key=lambda n: (n.lower(), n))
    allow = {a.lower() for a in ALLOWLIST}
    unique = {}
    for n in names:
        if n and n.lower() not in allow:
            unique.setdefault(n.lower(), n)
    return list(unique.values())


def read(path):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except FileNotFoundError:
        return None


def write_atomic(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".tmp-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(content)
        os.chmod(tmp, 0o644)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def render_map(names):
    # nginx geeft \b in een quoted string ongewijzigd door aan PCRE; re.escape levert
    # geen dubbele backslashes zolang een botnaam zelf geen backslash bevat.
    alternatives = "|".join(re.escape(n) for n in names if "\\" not in n and '"' not in n)
    return (
        "# Gegenereerd door ai-blocklist.service — niet handmatig wijzigen.\n"
        f"# Bron: {SOURCE_URL} ({len(names)} bots)\n"
        "map $http_user_agent $ai_bot {\n"
        "    default 0;\n"
        f'    "~*\\b(?:{alternatives})\\b" 1;\n'
        "}\n"
    )


def parse_groups(text):
    """Geef (user-agents in kleine letters, heeft `*`-groep) uit een robots.txt."""
    agents = set()
    for line in text.splitlines():
        line = line.split("#", 1)[0].strip()
        m = re.match(r"(?i)user-agent\s*:\s*(.+)", line)
        if m:
            agents.add(m.group(1).strip().lower())
    return agents, "*" in agents


def ends_with_open_group(text):
    """True als de laatste regel een User-agent zonder regels is: wat erachter komt
    zou anders bij die groep horen (bijv. `User-agent: *` + onze Disallow: /)."""
    for line in reversed(text.splitlines()):
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        return bool(re.match(r"(?i)user-agent\s*:", line))
    return False


def render_robots(site, names):
    base = read(os.path.join(site["webroot"], "robots.txt"))
    out = []
    if base is None or not base.strip():
        base = ""
    agents, has_star = parse_groups(base)

    if base:
        out.append(base.rstrip("\n"))
        if ends_with_open_group(base):
            out.append("Allow: /")
        out.append("")
    if site["noindex"] and not has_star:
        out += ["User-agent: *", "Disallow: /", ""]
        has_star = True

    # allowAgents: op deze site toegestaan (nginx laat ze via een eigen map door)
    allowed = {a.lower() for a in site.get("allowAgents", [])}
    missing = [n for n in names if n.lower() not in agents and n.lower() not in allowed]
    if missing:
        out.append("# AI-crawlers — toegevoegd door ai-blocklist.service")
        out += [f"User-agent: {n}" for n in missing]
        out += ["Disallow: /", ""]

    if not has_star:
        out += ["User-agent: *", "Allow: /", ""]
    if site["sitemap"] and not re.search(r"(?im)^\s*sitemap\s*:", base):
        out += [f"Sitemap: {site['sitemap']}", ""]
    return "\n".join(out).rstrip("\n") + "\n"


def nginx_test():
    exec_start = subprocess.run(
        ["systemctl", "show", "-p", "ExecStart", "--value", "nginx.service"],
        capture_output=True, text=True, check=True,
    ).stdout
    m = re.search(r"path=(\S+nginx)\b.*?-c '?([^' ;]+)", exec_start)
    if not m:
        raise RuntimeError(f"nginx-binary/config niet te bepalen uit ExecStart: {exec_start!r}")
    res = subprocess.run([m.group(1), "-t", "-c", m.group(2)], capture_output=True, text=True)
    for line in res.stderr.splitlines():
        # De bestaande proxy_headers_hash-waarschuwingen alleen tonen als de test faalt.
        if res.returncode != 0 or "[warn]" not in line:
            log(f"nginx -t: {line}")
    return res.returncode == 0


def main():
    with open(os.environ["SITES_JSON"], encoding="utf-8") as f:
        sites = json.load(f)

    fresh = True
    try:
        data = fetch_bots()
        if len(data) < MIN_BOTS:
            raise ValueError(f"slechts {len(data)} bots ontvangen (< {MIN_BOTS})")
    except Exception as e:  # netwerk- of parsefout: map ongemoeid laten
        log(f"WAARSCHUWING: botlijst niet bijgewerkt: {e}")
        fresh = False
        cached = read(CACHE_FILE)
        if cached is None:
            log("FOUT: geen eerder opgehaalde lijst; niets aangepast")
            return 1
        data = json.loads(cached)
        log(f"robots.txt-bestanden worden opgebouwd uit de vorige lijst ({len(data)} bots)")

    names = bot_names(data)
    log(f"{len(names)} AI-bots (allowlist: {', '.join(sorted(ALLOWLIST)) or '-'})")

    known = {n.lower() for n in names}
    for site in sites:
        for a in site.get("allowAgents", []):
            if a.lower() not in known:
                log(f"WAARSCHUWING: allowAgents {a!r} van {site['vhost']} staat niet in de botlijst")
        path = os.path.join(ROBOTS_DIR, f"{site['vhost']}.txt")
        content = render_robots(site, names)
        if read(path) != content:
            write_atomic(path, content)
            log(f"robots.txt bijgewerkt voor {site['vhost']}")

    if not fresh:
        return 0
    write_atomic(CACHE_FILE, json.dumps(data, indent=1, sort_keys=True) + "\n")

    new_map = render_map(names)
    old_map = read(MAP_FILE)
    if old_map == new_map:
        log("nginx-map ongewijzigd; geen reload nodig")
        return 0

    write_atomic(MAP_FILE, new_map)
    if not nginx_test():
        log("FOUT: nginx -t faalt met de nieuwe map; vorige versie teruggezet")
        if old_map is None:
            os.unlink(MAP_FILE)
        else:
            write_atomic(MAP_FILE, old_map)
        return 1
    subprocess.run(["systemctl", "reload", "nginx.service"], check=True)
    log("nginx-map bijgewerkt en nginx herladen")
    return 0


if __name__ == "__main__":
    sys.exit(main())
