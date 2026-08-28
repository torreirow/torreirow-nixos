#!/usr/bin/env python3
"""Status dashboard collector voor malandro.

Zet de gedeclareerde config (soll, uit /etc/status-page/configured.json,
gebakken door de NixOS-module) af tegen de live runtime-status (ist:
`docker ps -a`, `systemctl is-active`, `ss -tlnp`) en rendert per applicatie
een gezondheidsoordeel: gezond / kapot / orphan.

Serveert HTML op `/` en machine-leesbare JSON op `/status.json`.
Stdlib-only, luistert uitsluitend op 127.0.0.1. Elke databron zit in een
try/except zodat een uitgevallen bron de pagina niet sloopt (HTTP 200 met
een 'onbeschikbaar'-markering i.p.v. HTTP 500).
"""

import html
import json
import os
import re
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

CONFIGURED_JSON = os.environ.get("CONFIGURED_JSON", "/etc/status-page/configured.json")
PORT = int(os.environ.get("STATUS_PORT", "9099"))
BIND = os.environ.get("STATUS_BIND", "127.0.0.1")
DOCKER = os.environ.get("DOCKER_BIN", "docker")
SYSTEMCTL = os.environ.get("SYSTEMCTL_BIN", "systemctl")
SS = os.environ.get("SS_BIN", "ss")

# Oordeel-constanten
HEALTHY = "gezond"
BROKEN = "kapot"
ORPHAN = "orphan"
UNAVAILABLE = "onbeschikbaar"


def _run(cmd, timeout=5):
    """Voer een read-only commando uit; geef stdout terug of raise."""
    return subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=timeout,
        check=True,
    ).stdout


# --- soll -------------------------------------------------------------------

def load_configured():
    """Lees de gebakken config (soll). Faalt zacht naar lege inventaris."""
    try:
        with open(CONFIGURED_JSON, "r", encoding="utf-8") as fh:
            return json.load(fh), None
    except Exception as exc:  # noqa: BLE001 - robuustheid boven precisie
        return {"containers": [], "vhosts": [], "nativeServices": []}, str(exc)


# --- ist --------------------------------------------------------------------

def collect_docker():
    """Runtime-status van alle containers. Return (dict-by-name, error)."""
    try:
        out = _run([DOCKER, "ps", "-a", "--no-trunc", "--format", "{{json .}}"])
    except Exception as exc:  # noqa: BLE001
        return {}, str(exc)
    result = {}
    for line in out.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        # `docker ps` kan meerdere namen kommagescheiden geven
        name = (obj.get("Names") or "").split(",")[0].strip()
        if not name:
            continue
        # Ouder docker heeft geen 'State'; leid af uit 'Status'
        state = obj.get("State")
        status = obj.get("Status", "")
        if not state:
            state = "running" if status.lower().startswith("up") else "exited"
        result[name] = {
            "state": state,
            "status": status,
            "image": obj.get("Image", ""),
        }
    return result, None


def collect_services(names):
    """`systemctl is-active` per curated service. Return (dict, error)."""
    if not names:
        return {}, None
    result = {}
    try:
        for name in names:
            unit = name if name.endswith(".service") else name + ".service"
            proc = subprocess.run(
                [SYSTEMCTL, "is-active", unit],
                capture_output=True,
                text=True,
                timeout=5,
            )
            result[name] = proc.stdout.strip() or "unknown"
        return result, None
    except Exception as exc:  # noqa: BLE001
        return result, str(exc)


def collect_listening_ports():
    """Set van luisterende TCP-poorten uit `ss -H -tlnp`. Return (set, error)."""
    try:
        out = _run([SS, "-H", "-tlnp"])
    except Exception as exc:  # noqa: BLE001
        return set(), str(exc)
    ports = set()
    for line in out.splitlines():
        parts = line.split()
        if len(parts) < 4:
            continue
        local = parts[3]  # bv 127.0.0.1:9091, *:443, [::]:80
        m = re.search(r":(\d+)$", local)
        if m:
            ports.add(int(m.group(1)))
    return ports, None


def _port_from_upstream(upstream):
    """Haal een poortnummer uit een proxyPass zoals http://127.0.0.1:8095."""
    if not upstream:
        return None
    m = re.search(r"://[^/:]+:(\d+)", upstream)
    return int(m.group(1)) if m else None


def _is_local_upstream(upstream):
    """True als de proxyPass naar deze host wijst (poortcheck is dan zinvol)."""
    if not upstream:
        return False
    return bool(re.search(r"://(127\.0\.0\.1|0\.0\.0\.0|localhost|\[::1\])\b", upstream))


# --- merge ------------------------------------------------------------------

def build_report():
    configured, cfg_err = load_configured()
    docker_ist, docker_err = collect_docker()
    native_names = configured.get("nativeServices", [])
    services_ist, svc_err = collect_services(native_names)
    ports, ports_err = collect_listening_ports()

    report = {
        "containers": [],
        "nativeServices": [],
        "vhosts": [],
        "sources": {
            "configured": UNAVAILABLE if cfg_err else "ok",
            "docker": UNAVAILABLE if docker_err else "ok",
            "systemd": UNAVAILABLE if svc_err else "ok",
            "ports": UNAVAILABLE if ports_err else "ok",
        },
        "errors": {
            k: v
            for k, v in {
                "configured": cfg_err,
                "docker": docker_err,
                "systemd": svc_err,
                "ports": ports_err,
            }.items()
            if v
        },
    }

    seen_containers = set()

    # Containers: soll x ist
    for c in configured.get("containers", []):
        name = c.get("name")
        seen_containers.add(name)
        ist = docker_ist.get(name)
        if docker_err:
            verdict = UNAVAILABLE
            state = UNAVAILABLE
        elif ist and ist["state"] == "running":
            verdict = HEALTHY
            state = ist["status"]
        elif ist:
            verdict = BROKEN
            state = ist["status"]
        else:
            verdict = BROKEN
            state = "afwezig"
        report["containers"].append({
            "name": name,
            "image": c.get("image", ""),
            "declared": True,
            "verdict": verdict,
            "state": state,
        })

    # Orphan-containers: draaien maar niet gedeclareerd
    if not docker_err:
        for name, ist in sorted(docker_ist.items()):
            if name in seen_containers:
                continue
            report["containers"].append({
                "name": name,
                "image": ist.get("image", ""),
                "declared": False,
                "verdict": ORPHAN,
                "state": ist.get("status", ""),
            })

    # Native services
    for name in native_names:
        active = services_ist.get(name, "unknown")
        if svc_err:
            verdict = UNAVAILABLE
        elif active == "active":
            verdict = HEALTHY
        else:
            verdict = BROKEN
        report["nativeServices"].append({
            "name": name,
            "active": active,
            "verdict": verdict,
        })

    # Vhosts (best-effort: check of upstream-poort luistert)
    for v in configured.get("vhosts", []):
        upstream = v.get("proxyPass")
        port = _port_from_upstream(upstream)
        if v.get("redirect"):
            kind, verdict = "redirect", HEALTHY
        elif upstream is None:
            kind, verdict = "static/overig", HEALTHY
        elif not _is_local_upstream(upstream):
            # Externe upstream: niet lokaal verifieerbaar via ss.
            kind, verdict = "proxy (extern)", HEALTHY
        elif ports_err:
            kind, verdict = "proxy", UNAVAILABLE
        elif port in ports:
            kind, verdict = "proxy", HEALTHY
        else:
            kind, verdict = "proxy", BROKEN
        report["vhosts"].append({
            "name": v.get("name"),
            "kind": kind,
            "upstream": upstream or v.get("redirect") or "",
            "verdict": verdict,
        })

    # Samenvatting
    all_items = report["containers"] + report["nativeServices"] + report["vhosts"]
    report["summary"] = {
        HEALTHY: sum(1 for i in all_items if i["verdict"] == HEALTHY),
        BROKEN: sum(1 for i in all_items if i["verdict"] == BROKEN),
        ORPHAN: sum(1 for i in all_items if i["verdict"] == ORPHAN),
        UNAVAILABLE: sum(1 for i in all_items if i["verdict"] == UNAVAILABLE),
    }
    return report


# --- render -----------------------------------------------------------------

VERDICT_STYLE = {
    HEALTHY: ("#1a7f37", "✓"),
    BROKEN: ("#cf222e", "✗"),
    ORPHAN: ("#9a6700", "⚠"),
    UNAVAILABLE: ("#57606a", "?"),
}


def _badge(verdict):
    color, icon = VERDICT_STYLE.get(verdict, ("#57606a", "?"))
    return (
        f'<span class="badge" style="background:{color}">'
        f'{icon} {html.escape(verdict)}</span>'
    )


def _row(cells):
    return "<tr>" + "".join(f"<td>{c}</td>" for c in cells) + "</tr>"


def render_html(report):
    s = report["summary"]
    src = report["sources"]
    parts = [
        "<!DOCTYPE html><html lang='nl'><head><meta charset='utf-8'>",
        "<meta name='viewport' content='width=device-width, initial-scale=1'>",
        "<title>Status — malandro</title>",
        "<style>",
        "*{box-sizing:border-box}",
        "body{font-family:-apple-system,Segoe UI,Roboto,sans-serif;",
        "background:#f6f8fa;color:#1f2328;margin:0;padding:2rem}",
        "h1{font-size:1.5rem;margin:0 0 .25rem}",
        ".sub{color:#57606a;margin:0 0 1.5rem;font-size:.9rem}",
        "h2{font-size:1.1rem;margin:2rem 0 .5rem}",
        "table{border-collapse:collapse;width:100%;background:#fff;",
        "border:1px solid #d0d7de;border-radius:6px;overflow:hidden}",
        "th,td{text-align:left;padding:.5rem .75rem;border-bottom:1px solid #eaeef2;",
        "font-size:.9rem}",
        "th{background:#f6f8fa;font-weight:600}",
        "tr:last-child td{border-bottom:none}",
        ".badge{color:#fff;padding:.1rem .5rem;border-radius:999px;",
        "font-size:.8rem;white-space:nowrap}",
        ".sum span{margin-right:1rem;font-weight:600}",
        ".src{font-size:.8rem;color:#57606a;margin-top:.5rem}",
        "code{background:#eaeef2;padding:.1rem .3rem;border-radius:4px}",
        "</style></head><body>",
        "<h1>Service-status malandro</h1>",
        "<p class='sub'>soll (Nix-config) × ist (live) — live per request</p>",
        "<p class='sum'>",
        f"<span style='color:#1a7f37'>✓ {s[HEALTHY]} gezond</span>",
        f"<span style='color:#cf222e'>✗ {s[BROKEN]} kapot</span>",
        f"<span style='color:#9a6700'>⚠ {s[ORPHAN]} orphan</span>",
        f"<span style='color:#57606a'>? {s[UNAVAILABLE]} onbeschikbaar</span>",
        "</p>",
    ]

    if report["errors"]:
        parts.append("<p class='src'>Databronnen: " + ", ".join(
            f"{html.escape(k)}=<code>{html.escape(str(vv))}</code>"
            for k, vv in src.items()
        ) + "</p>")

    # Containers
    parts.append("<h2>Docker-containers</h2><table>")
    parts.append(_row(["Naam", "Image", "Gedeclareerd", "Status", "Oordeel"]))
    for c in report["containers"]:
        parts.append(_row([
            html.escape(c["name"] or ""),
            f"<code>{html.escape(c['image'])}</code>" if c["image"] else "",
            "ja" if c["declared"] else "nee",
            html.escape(str(c["state"])),
            _badge(c["verdict"]),
        ]))
    parts.append("</table>")

    # Native services
    parts.append("<h2>Native services</h2><table>")
    parts.append(_row(["Service", "systemd", "Oordeel"]))
    for n in report["nativeServices"]:
        parts.append(_row([
            html.escape(n["name"]),
            html.escape(n["active"]),
            _badge(n["verdict"]),
        ]))
    parts.append("</table>")

    # Vhosts
    parts.append("<h2>Nginx virtualHosts</h2><table>")
    parts.append(_row(["Host", "Type", "Upstream", "Oordeel"]))
    for v in report["vhosts"]:
        parts.append(_row([
            html.escape(v["name"] or ""),
            html.escape(v["kind"]),
            f"<code>{html.escape(v['upstream'])}</code>" if v["upstream"] else "",
            _badge(v["verdict"]),
        ]))
    parts.append("</table>")

    parts.append("</body></html>")
    return "".join(parts)


# --- http -------------------------------------------------------------------

class Handler(BaseHTTPRequestHandler):
    server_version = "status-page/1.0"

    def _send(self, code, body, content_type):
        data = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(data)

    def do_GET(self):  # noqa: N802 - stdlib API
        path = self.path.split("?", 1)[0]
        try:
            report = build_report()
        except Exception as exc:  # noqa: BLE001 - laatste vangnet
            self._send(200, json.dumps({"error": str(exc)}), "application/json")
            return
        if path == "/status.json":
            self._send(200, json.dumps(report, indent=2), "application/json")
        elif path in ("/", "/index.html"):
            self._send(200, render_html(report), "text/html; charset=utf-8")
        else:
            self._send(404, "not found", "text/plain")

    do_HEAD = do_GET

    def log_message(self, *args):  # stil: journald doet de logging al
        pass


def main():
    server = ThreadingHTTPServer((BIND, PORT), Handler)
    print(f"status-page luistert op {BIND}:{PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
