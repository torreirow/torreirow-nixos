#!/usr/bin/env python3
"""vuln-radar: version-aware CVE dashboard.

Leest een gedeclareerde asset-inventaris, matcht per package de geinstalleerde
versie tegen distro-/vendor-data en toont alleen aantoonbaar toepasselijke
CVE's. FreshRSS wordt read-only gebruikt voor titel/link/context.

Stdlib + python-debian. Luistert alleen op 127.0.0.1.
"""

import html
import json
import os
import re
import sqlite3
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from debian.debian_support import Version

ASSETS_FILE = os.environ.get("VULN_RADAR_ASSETS", "/etc/vuln-radar/assets.json")
DATA_DIR = os.environ.get("VULN_RADAR_DATA", "/var/lib/vuln-radar")
PORT = int(os.environ.get("VULN_RADAR_PORT", "9101"))
FRESHRSS_DB = os.environ.get("FRESHRSS_DB", "/var/lib/freshrss/users/wouter/db.sqlite")
CACHE_DB = os.path.join(DATA_DIR, "cache.sqlite")
REFRESH_INTERVAL = int(os.environ.get("VULN_RADAR_REFRESH", str(6 * 3600)))
HTTP_TIMEOUT = 120

CVE_RE = re.compile(r"CVE-\d{4}-\d{4,}")
STATE = {
    "assets": {},
    "results": [],
    "unknown": 0,
    "errors": [],
    "last_refresh": None,
    "loading": True,
}
LOCK = threading.Lock()


# --- cache -----------------------------------------------------------------

def db():
    conn = sqlite3.connect(CACHE_DB, timeout=30)
    conn.execute(
        "CREATE TABLE IF NOT EXISTS http_cache ("
        "url TEXT PRIMARY KEY, fetched_at INTEGER NOT NULL, body BLOB NOT NULL)"
    )
    return conn


def cache_get(url):
    try:
        with db() as conn:
            row = conn.execute(
                "SELECT fetched_at, body FROM http_cache WHERE url = ?", (url,)
            ).fetchone()
    except Exception:
        return None
    if not row:
        return None
    return row[0], row[1]


def cache_put(url, body):
    try:
        with db() as conn:
            conn.execute(
                "INSERT OR REPLACE INTO http_cache (url, fetched_at, body) VALUES (?, ?, ?)",
                (url, int(time.time()), body),
            )
    except Exception:
        pass


def fetch(url, max_age, timeout=HTTP_TIMEOUT):
    """Return (text, error). A stale cache is returned on failure."""
    cached = cache_get(url)
    if cached and int(time.time()) - cached[0] <= max_age:
        try:
            return cached[1].decode("utf-8", "replace"), None
        except Exception:
            pass
    try:
        req = urllib.request.Request(
            url,
            headers={
                "User-Agent": "vuln-radar/1.0 (+https://toorren.net)",
                "Accept": "text/html,application/json,application/xml;q=0.9,*/*;q=0.1",
            },
        )
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read()
        cache_put(url, body)
        return body.decode("utf-8", "replace"), None
    except Exception as exc:  # noqa: BLE001
        if cached:
            return cached[1].decode("utf-8", "replace"), f"{url}: {exc} (stale cache)"
        return None, f"{url}: {exc}"


# --- helpers ---------------------------------------------------------------

def version_lt(a, b):
    try:
        return Version(a) < Version(b)
    except Exception:
        return False


def clean_text(value):
    text = re.sub(r"<[^>]+>", " ", value or "")
    text = html.unescape(text)
    return re.sub(r"\s+", " ", text).strip()


def severity_rank(sev):
    return {"critical": 0, "major": 1, "important": 1, "high": 1, "medium": 2, "moderate": 2, "minor": 3, "low": 3}.get((sev or "").lower(), 9)


def make_result(asset, pkg, source, installed, cve, fixed, severity, title, link, **extra):
    item = {
        "asset": asset,
        "package": pkg,
        "source": source,
        "installed": installed,
        "cve": cve,
        "fixed": fixed or "onbekend",
        "severity": severity or "unknown",
        "title": title or "",
        "link": link or "",
        "kev": bool(extra.pop("kev", False)),
        "esm_required": bool(extra.pop("esm_required", False)),
        "context": extra.pop("context", []),
    }
    item.update(extra)
    return item


def add_context(results, contexts):
    for item in results:
        item["context"] = contexts.get(item["cve"], [])[:3]


# --- Debian ----------------------------------------------------------------

DEBIAN_URL = "https://security-tracker.debian.org/tracker/data/json"


def debian_match(asset, pkg, installed, data, contexts):
    out = []
    pkg_data = data.get(pkg)
    if not pkg_data:
        return out, 0
    unknown = 0
    for cve, info in pkg_data.items():
        rel = (info.get("releases") or {}).get(asset["release"])
        if not rel:
            continue
        fixed = rel.get("fixed_version") or ""
        status = (rel.get("status") or "").lower()
        if fixed in ("", "0", "n/a"):
            if status in ("open", "vulnerable", "undetermined"):
                unknown += 1
            continue
        if version_lt(installed, fixed):
            out.append(
                make_result(
                    asset_name(asset), pkg, "dpkg", installed, cve, fixed,
                    rel.get("urgency") or "unknown", (info.get("description") or "")[:220],
                    f"https://security-tracker.debian.org/tracker/{cve}",
                    context=contexts.get(cve, []),
                )
            )
    return out, unknown


# --- Ubuntu ----------------------------------------------------------------

UBUNTU_URL = "https://ubuntu.com/security/cves.json?package="


def ubuntu_match(asset, pkg, installed, contexts):
    url = UBUNTU_URL + urllib.parse.quote(pkg, safe="")
    text, error = fetch(url, 6 * 3600)
    if text is None:
        return [], 0, [error]
    try:
        data = json.loads(text)
    except Exception as exc:  # noqa: BLE001
        return [], 0, [f"{url}: {exc}"]
    out = []
    unknown = 0
    for cve in data.get("cves", []):
        statuses = []
        for package in cve.get("packages", []):
            if package.get("name") == pkg:
                statuses = package.get("statuses") or []
                break
        rel = None
        for status in statuses:
            if status.get("release_codename") == asset["release"]:
                rel = status
                break
        if rel is None:
            continue
        fixed = (rel.get("description") or "").strip()
        pocket = (rel.get("pocket") or "").lower()
        state = (rel.get("status") or "").lower()
        esm_required = pocket.startswith("esm") and not asset.get("esm", False)
        if not fixed or state not in ("released", "fixed"):
            if state in ("needed", "pending", "deferred"):
                unknown += 1
            continue
        if version_lt(installed, fixed):
            sev = cve.get("priority") or "unknown"
            impact = cve.get("impact") or {}
            base = (impact.get("baseMetricV3") or {}).get("cvssV3") or {}
            sev = base.get("baseSeverity") or sev
            out.append(
                make_result(
                    asset_name(asset), pkg, "dpkg", installed, cve.get("id", ""), fixed,
                    sev, (cve.get("description") or "")[:220],
                    f"https://ubuntu.com/security/{cve.get('id', '')}",
                    esm_required=esm_required,
                    context=contexts.get(cve.get("id", ""), []),
                )
            )
    return out, unknown, []


# --- upstream: PHP / nginx / Apache ---------------------------------------

PHP_URL = "https://www.php.net/ChangeLog-8.php"
NGINX_URL = "https://nginx.org/en/security_advisories.html"
APACHE_URL = "https://httpd.apache.org/security/vulnerabilities_24.html"


def php_fixed():
    text, error = fetch(PHP_URL, 24 * 3600)
    if text is None:
        return {}, [error]
    parts = re.split(r"Version\s+(\d+\.\d+\.\d+)", text)
    fixed = {}
    for i in range(1, len(parts) - 1, 2):
        ver, body = parts[i], parts[i + 1]
        branch = ".".join(ver.split(".")[:2])
        for cve in CVE_RE.findall(body):
            current = fixed.get(cve, {}).get(branch)
            if current is None or version_lt(ver, current):
                fixed.setdefault(cve, {})[branch] = ver
    return fixed, []


def nginx_fixed():
    text, error = fetch(NGINX_URL, 24 * 3600)
    if text is None:
        return {}, [error]
    fixed = {}
    blocks = re.split(r"Advisory\s+(?=CVE-\d{4}-\d+)", text)
    for block in blocks:
        m = re.search(r"(CVE-\d{4}-\d+)", block)
        if not m:
            continue
        cve = m.group(1)
        nv = re.search(r"Not vulnerable:\s*([^\n]+)", block)
        nv_versions = re.findall(r"\d+\.\d+\.\d+", nv.group(1)) if nv else []
        vuln = re.search(r"Vulnerable:\s*([0-9.]+)\s*-\s*([0-9.]+)", block)
        sev = re.search(r"Severity:\s*(\w+)", block)
        fixed[cve] = {
            "fixed": nv_versions[0] if nv_versions else None,
            "nv_versions": nv_versions,
            "vuln_min": vuln.group(1) if vuln else None,
            "vuln_max": vuln.group(2) if vuln else None,
            "severity": (sev.group(1).lower() if sev else "unknown"),
        }
    return fixed, []


def apache_fixed():
    text, error = fetch(APACHE_URL, 24 * 3600)
    if text is None:
        return {}, [error]
    parts = re.split(r"Fixed in Apache HTTP Server\s+(\d+\.\d+\.\d+)", text)
    fixed = {}
    for i in range(1, len(parts) - 1, 2):
        ver, body = parts[i], parts[i + 1]
        for m in re.finditer(r"(CVE-\d{4}-\d+)\s*\((critical|important|moderate|low)\)", body):
            fixed[m.group(1)] = {"fixed": ver, "severity": m.group(2).lower()}
        for cve in CVE_RE.findall(body):
            fixed.setdefault(cve, {"fixed": ver, "severity": "unknown"})
    return fixed, []


def upstream_match(asset, pkg, installed, php, nginx, apache, contexts, source="upstream"):
    out = []
    unknown = 0
    pkg_l = pkg.lower()
    if pkg_l.startswith("php"):
        branch = ".".join(installed.split(".")[:2])
        for cve, branches in php.items():
            fixed = branches.get(branch)
            if fixed and version_lt(installed, fixed):
                out.append(
                    make_result(asset_name(asset), pkg, source, installed, cve, fixed,
                                "unknown", "", PHP_URL, context=contexts.get(cve, []))
                )
    elif pkg_l.startswith("nginx"):
        for cve, info in nginx.items():
            nv_versions = info.get("nv_versions") or ([info["fixed"]] if info.get("fixed") else [])
            if any(not version_lt(installed, v) for v in nv_versions):
                continue
            vmin, vmax = info.get("vuln_min"), info.get("vuln_max")
            applies = bool(vmin and vmax and not version_lt(installed, vmin) and not version_lt(vmax, installed))
            if applies:
                newer = [v for v in nv_versions if version_lt(installed, v)]
                fixed = min(newer, key=Version) if newer else info.get("fixed")
                out.append(
                    make_result(asset_name(asset), pkg, source, installed, cve, fixed,
                                info.get("severity"), "", NGINX_URL,
                                context=contexts.get(cve, []))
                )
    elif pkg_l.startswith("apache") or pkg_l.startswith("httpd"):
        for cve, info in apache.items():
            fixed = info.get("fixed")
            if fixed and version_lt(installed, fixed):
                out.append(
                    make_result(asset_name(asset), pkg, source, installed, cve, fixed,
                                info.get("severity"), "", APACHE_URL,
                                context=contexts.get(cve, []))
                )
    else:
        unknown += 1
    return out, unknown


# --- Nix / NVD / KEV -------------------------------------------------------

def nvd_lookup(cve):
    url = "https://services.nvd.nist.gov/rest/json/cves/2.0?cveId=" + urllib.parse.quote(cve)
    text, error = fetch(url, 24 * 3600, timeout=60)
    if text is None:
        return None, [error]
    try:
        data = json.loads(text)
        vuln = (data.get("vulnerabilities") or [{}])[0].get("cve", {})
        metrics = vuln.get("metrics") or {}
        for key in ("cvssMetricV31", "cvssMetricV30", "cvssMetricV2"):
            items = metrics.get(key) or []
            if items:
                return items[0].get("cvssData", {}).get("baseSeverity"), []
    except Exception as exc:  # noqa: BLE001
        return None, [f"{url}: {exc}"]
    return None, []


def vulnix_match(asset, pkg, installed, contexts):
    path = "/var/lib/vulnix/vulnix.json"
    try:
        with open(path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except Exception:
        return None
    if isinstance(data, dict):
        data = data.get("vulnerabilities") or data.get("packages") or []
    if not isinstance(data, list):
        return None
    out = []
    found = False
    seen = set()
    pkg_l = pkg.lower()
    for item in data:
        if not isinstance(item, dict):
            continue
        name = item.get("name") or item.get("pname") or ""
        name_l = name.lower()
        if not name_l:
            continue
        if not (name_l == pkg_l or name_l.startswith(pkg_l + "-") or name_l.startswith(pkg_l + ".")):
            continue
        found = True
        cves = item.get("affected_by") or item.get("cves") or item.get("cve") or []
        if isinstance(cves, str):
            cves = [cves]
        for cve in cves:
            cve_id = cve if isinstance(cve, str) else (cve.get("id") or cve.get("cve") or "")
            if not cve_id.startswith("CVE-") or cve_id in seen:
                continue
            seen.add(cve_id)
            out.append(
                make_result(asset_name(asset), pkg, "nix", installed, cve_id, "onbekend",
                            "unknown", item.get("summary") or "", "",
                            context=contexts.get(cve_id, []))
            )
    return out if found else None


KEV_URL = "https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json"


def kev_map():
    text, error = fetch(KEV_URL, 24 * 3600)
    if text is None:
        return {}, [error]
    try:
        data = json.loads(text)
        return {v["cveID"]: v for v in data.get("vulnerabilities", []) if v.get("cveID")}, []
    except Exception as exc:  # noqa: BLE001
        return {}, [f"{KEV_URL}: {exc}"]


# --- FreshRSS context ------------------------------------------------------

def fresh_context():
    if not os.path.exists(FRESHRSS_DB):
        return {}, ["FreshRSS-database niet gevonden"]
    try:
        conn = sqlite3.connect(f"file:{FRESHRSS_DB}?mode=ro", uri=True, timeout=10)
        rows = conn.execute(
            "SELECT e.title, e.content, e.link, e.date, f.name FROM entry e "
            "JOIN feed f ON f.id = e.id_feed "
            "WHERE e.title LIKE '%CVE-%' OR e.content LIKE '%CVE-%'"
        ).fetchall()
        conn.close()
    except Exception as exc:  # noqa: BLE001
        return {}, [f"FreshRSS: {exc}"]
    out = {}
    for title, content, link, date, feed in rows:
        blob = (title or "") + " " + clean_text(content)
        for cve in set(CVE_RE.findall(blob)):
            out.setdefault(cve, []).append({
                "title": clean_text(title)[:160],
                "link": link,
                "feed": feed,
                "date": datetime.fromtimestamp(int(date or 0), timezone.utc).strftime("%Y-%m-%d"),
            })
    return out, []


# --- matching --------------------------------------------------------------

def asset_name(asset):
    return asset.get("_name", "")


def match_asset(asset, deps, contexts):
    out = []
    unknown = 0
    errors = []
    for pkg, installed in (asset.get("dpkg") or {}).items():
        if asset.get("os") == "debian":
            res, unk = debian_match(asset, pkg, installed, deps["debian"], contexts)
            out += res
            unknown += unk
        elif asset.get("os") == "ubuntu":
            res, unk, errs = ubuntu_match(asset, pkg, installed, contexts)
            out += res
            unknown += unk
            errors += errs
        else:
            unknown += 1
    for pkg, installed in (asset.get("nix") or {}).items():
        res = vulnix_match(asset, pkg, installed, contexts) if asset.get("os") == "nixos" else None
        if res is not None:
            out += res
            continue
        res, unk = upstream_match(
            asset, pkg, installed, deps["php"], deps["nginx"], deps["apache"], contexts,
            source="nix",
        )
        if res or pkg.lower().startswith(("php", "nginx", "apache", "httpd")):
            out += res
            unknown += unk
        else:
            unknown += 1
    for pkg, installed in (asset.get("upstream") or {}).items():
        res, unk = upstream_match(
            asset, pkg, installed, deps["php"], deps["nginx"], deps["apache"], contexts
        )
        out += res
        unknown += unk
    out.sort(key=lambda item: (severity_rank(item["severity"]), item["cve"]))
    return out, unknown, errors


def refresh():
    with LOCK:
        STATE["loading"] = True
    errors = []
    try:
        with open(ASSETS_FILE, "r", encoding="utf-8") as fh:
            assets = json.load(fh)
    except Exception as exc:  # noqa: BLE001
        with LOCK:
            STATE.update({"loading": False, "errors": [f"assets: {exc}"]})
        return

    debian_text, err = fetch(DEBIAN_URL, 24 * 3600)
    errors += [err] if err else []
    try:
        debian_data = json.loads(debian_text) if debian_text else {}
    except Exception as exc:  # noqa: BLE001
        debian_data = {}
        errors.append(f"debian: {exc}")

    php_data, errs = php_fixed()
    errors += errs
    nginx_data, errs = nginx_fixed()
    errors += errs
    apache_data, errs = apache_fixed()
    errors += errs
    kev, errs = kev_map()
    errors += errs
    contexts, errs = fresh_context()
    errors += errs

    deps = {"debian": debian_data, "php": php_data, "nginx": nginx_data, "apache": apache_data}
    results = []
    total_unknown = 0
    for name, raw in assets.items():
        asset = dict(raw)
        asset["_name"] = name
        if not asset.get("release"):
            errors.append(f"{name}: release ontbreekt")
            continue
        matched, unknown, errs = match_asset(asset, deps, contexts)
        errors += errs
        for item in matched:
            if item["cve"] in kev:
                item["kev"] = True
                item["kev_date"] = kev[item["cve"]].get("dateAdded")
        packages = []
        declared = {}
        for source in ("dpkg", "nix", "upstream"):
            for pkg, installed in (asset.get(source) or {}).items():
                declared[(source, pkg)] = installed
        for source, pkg in declared:
            installed = declared[(source, pkg)]
            cves = [item for item in matched if item["source"] == source and item["package"] == pkg]
            packages.append({
                "source": source,
                "package": pkg,
                "installed": installed,
                "status": "affected" if cves else "clean",
                "cves": cves,
            })
        results.append({
            "name": name,
            "os": asset.get("os"),
            "release": asset.get("release"),
            "esm": bool(asset.get("esm")),
            "packages": packages,
        })
        total_unknown += unknown

    with LOCK:
        STATE.update({
            "assets": assets,
            "results": results,
            "unknown": total_unknown,
            "errors": errors,
            "last_refresh": datetime.now(timezone.utc).isoformat(),
            "loading": False,
        })


def refresh_loop():
    while True:
        try:
            refresh()
        except Exception as exc:  # noqa: BLE001
            with LOCK:
                STATE.update({"loading": False, "errors": [f"refresh: {exc}"]})
        time.sleep(REFRESH_INTERVAL)


# --- rendering -------------------------------------------------------------

def counts(results):
    c = {"critical": 0, "high": 0, "medium": 0, "low": 0, "unknown": 0, "kev": 0, "total": 0}
    for asset in results:
        for package in asset["packages"]:
            for item in package["cves"]:
                c["total"] += 1
                sev = (item.get("severity") or "unknown").lower()
                if sev in ("critical",):
                    c["critical"] += 1
                elif sev in ("high", "major", "important"):
                    c["high"] += 1
                elif sev in ("medium", "moderate"):
                    c["medium"] += 1
                elif sev in ("low", "minor"):
                    c["low"] += 1
                else:
                    c["unknown"] += 1
                if item.get("kev"):
                    c["kev"] += 1
    return c


def render_html(state, query):
    results = state["results"]
    severity_filter = (query.get("severity", [""])[0] or "").lower()
    asset_filter = (query.get("asset", [""])[0] or "")
    c = counts(results)
    rows = []
    for asset in results:
        if asset_filter and asset["name"] != asset_filter:
            continue
        package_rows = []
        for package in asset["packages"]:
            cves = [i for i in package["cves"] if not severity_filter or (i.get("severity") or "").lower() == severity_filter]
            if package["cves"] and not cves:
                continue
            if cves:
                items = "".join(
                    "<li><span class='sev {sev}'>{sev}</span> "
                    "<a href='{link}'>{cve}</a> "
                    "<span class='muted'>fixed {fixed}</span>"
                    "{kev}{ctx}</li>".format(
                        sev=html.escape((i.get("severity") or "unknown")),
                        link=html.escape(i.get("link") or "#"),
                        cve=html.escape(i["cve"]),
                        fixed=html.escape(i.get("fixed") or "onbekend"),
                        kev=" <span class='kev'>KEV</span>" if i.get("kev") else "",
                        ctx=(" <span class='muted'>" + html.escape(i["context"][0]["feed"]) + "</span>") if i.get("context") else "",
                    )
                    for i in cves
                )
                package_rows.append(
                    f"<tr><td>{html.escape(package['source'])}</td><td>{html.escape(package['package'])}</td>"
                    f"<td>{html.escape(package['installed'])}</td><td><ul>{items}</ul></td></tr>"
                )
            else:
                package_rows.append(
                    f"<tr><td>{html.escape(package['source'])}</td><td>{html.escape(package['package'])}</td>"
                    f"<td>{html.escape(package['installed'])}</td><td class='clean'>geen toepasselijke CVE</td></tr>"
                )
        rows.append(
            f"<h2>{html.escape(asset['name'])} <span class='muted'>{html.escape(asset['os'])} "
            f"{html.escape(asset['release'])}</span></h2>"
            f"<table><thead><tr><th>Bron</th><th>Package</th><th>Versie</th><th>Toepasselijk</th></tr></thead>"
            f"<tbody>{''.join(package_rows)}</tbody></table>"
        )
    errors = "".join(f"<li>{html.escape(e)}</li>" for e in state["errors"][:8])
    refresh = html.escape(state["last_refresh"] or "nog niet")
    body = f"""
    <p class="muted">Laatst ververst: {refresh} · onbekend: {state['unknown']}</p>
    <div class="cards">
      <div><b>{c['critical']}</b><span>critical</span></div>
      <div><b>{c['high']}</b><span>high</span></div>
      <div><b>{c['medium']}</b><span>medium</span></div>
      <div><b>{c['kev']}</b><span>KEV</span></div>
      <div><b>{c['total']}</b><span>totaal</span></div>
    </div>
    {('<p class="error">Bronfouten:<ul>' + errors + '</ul></p>') if errors else ''}
    {''.join(rows) if rows else '<p>Geen assets of nog geen data.</p>'}
    """
    return f"""<!doctype html><html lang="nl"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Vuln radar</title><style>
body{{background:#18222c;color:#e8eef4;font:15px/1.5 system-ui,sans-serif;margin:0;padding:2rem}}
h1,h2{{font-weight:600}} h2{{margin-top:2rem}} a{{color:#8fd3ff}}
table{{width:100%;border-collapse:collapse;margin:.5rem 0 1.5rem}}
th,td{{text-align:left;padding:.4rem .6rem;border-bottom:1px solid #2c3a47;vertical-align:top}}
.muted{{color:#8fa3b5}} .clean{{color:#7bc47b}}
.cards{{display:flex;gap:1rem;flex-wrap:wrap;margin:1rem 0}}
.cards div{{background:#202d3a;border:1px solid #2c3a47;border-radius:6px;padding:.6rem 1rem;min-width:90px}}
.cards b{{display:block;font-size:1.6rem}} .cards span{{color:#8fa3b5}}
.sev{{display:inline-block;min-width:5.5rem;font-size:.75rem;text-transform:uppercase}}
.critical{{color:#ff6b6b}} .high,.major,.important{{color:#ffb347}} .medium,.moderate{{color:#ffe066}} .low,.minor{{color:#9ad0ff}}
.kev{{background:#7a1f1f;color:#ffd7d7;border-radius:3px;padding:0 .3rem;font-size:.7rem}}
.error{{color:#ffb3b3}} ul{{margin:.2rem 0 .2rem 1.1rem;padding:0}}
</style></head><body><h1>Vuln radar</h1>
<p class="muted">Alleen CVE's waarvan de geïnstalleerde versie onder de fixed version ligt.</p>
{body}</body></html>"""


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):  # noqa: N802
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/vulns.json":
            with LOCK:
                payload = {
                    "assets": STATE["results"],
                    "unknown": STATE["unknown"],
                    "errors": STATE["errors"],
                    "last_refresh": STATE["last_refresh"],
                }
            self.send(200, "application/json", json.dumps(payload, indent=2).encode())
            return
        if parsed.path == "/healthz":
            self.send(200, "text/plain", b"ok\n")
            return
        with LOCK:
            state = dict(STATE)
        query = urllib.parse.parse_qs(parsed.query)
        self.send(200, "text/html; charset=utf-8", render_html(state, query).encode())

    def send(self, code, ctype, body):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        return


def main():
    os.makedirs(DATA_DIR, exist_ok=True)
    threading.Thread(target=refresh_loop, daemon=True).start()
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    server.serve_forever()


if __name__ == "__main__":
    main()
