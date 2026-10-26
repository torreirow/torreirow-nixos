#!/usr/bin/env python3
"""Ontvang Vikunja-webhooks en stuur ze door als Signal-bericht.

Vikunja POST een JSON-envelop {event_name, time, data} en ondertekent de body met
HMAC-SHA256 (header X-Vikunja-Signature, hex). Alleen correct ondertekende
verzoeken worden doorgestuurd naar de lokale signal-cli REST API.

Bedoeld voor de user-level webhook in Vikunja (Instellingen → Webhooks) met de
events task.reminder.fired en tasks.overdue; andere (project-)events krijgen een
generieke regel, zodat een extra aangevinkt event niet stilletjes verdwijnt.

Omgeving:
  VIKUNJA_WEBHOOK_SECRET   gedeeld geheim, zelfde als in de Vikunja-webhook (verplicht)
  SIGNAL_SENDER            afzendnummer (modules/signal-numbers.nix)
  SIGNAL_RECIPIENT         ontvanger (modules/signal-numbers.nix)
  LISTEN_PORT              default 8100, altijd op 127.0.0.1
"""
import hashlib
import hmac
import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from zoneinfo import ZoneInfo

SIGNAL_API = "http://127.0.0.1:8088/v2/send"
TASKS_URL = "https://tasks.toorren.net/tasks/{}"
TZ = ZoneInfo("Europe/Amsterdam")
MAX_BODY = 1024 * 1024
MAX_LISTED = 15  # zoveel taken tonen we bij tasks.overdue, de rest als "+N"

SECRET = os.environ.get("VIKUNJA_WEBHOOK_SECRET", "").encode()
SIGNAL_SENDER = os.environ.get("SIGNAL_SENDER")
SIGNAL_RECIPIENT = os.environ.get("SIGNAL_RECIPIENT")


def log(msg):
    print(msg, file=sys.stderr, flush=True)


def fmt_date(value):
    """Vikunja-tijdstip → '28-10 10:00'; None voor de nul-datum (geen deadline)."""
    if not value or value.startswith("0001-"):
        return None
    try:
        return datetime.fromisoformat(value).astimezone(TZ).strftime("%d-%m %H:%M")
    except ValueError:
        return value


def task_line(task, projects=None):
    title = task.get("title") or "(zonder titel)"
    parts = []
    project = (projects or {}).get(str(task.get("project_id")))
    if project and project.get("title"):
        parts.append(project["title"])
    due = fmt_date(task.get("due_date"))
    if due:
        parts.append(f"deadline {due}")
    return f"{title} ({', '.join(parts)})" if parts else title


def task_block(task, project):
    lines = [task.get("title") or "(zonder titel)"]
    if project and project.get("title"):
        lines.append(f"Project: {project['title']}")
    due = fmt_date(task.get("due_date"))
    if due:
        lines.append(f"Deadline: {due}")
    if task.get("id"):
        lines.append(TASKS_URL.format(task["id"]))
    return "\n".join(lines)


def format_message(payload):
    event = payload.get("event_name", "?")
    data = payload.get("data") or {}

    if event == "task.reminder.fired":
        return "⏰ Herinnering\n" + task_block(data.get("task") or {}, data.get("project"))

    if event == "task.overdue":
        return "⚠️ Over tijd\n" + task_block(data.get("task") or {}, data.get("project"))

    if event == "tasks.overdue":
        tasks = data.get("tasks") or []
        projects = data.get("projects") or {}
        lines = [f"⚠️ {len(tasks)} taak/taken over tijd"]
        lines += [f"• {task_line(t, projects)}" for t in tasks[:MAX_LISTED]]
        if len(tasks) > MAX_LISTED:
            lines.append(f"… en nog {len(tasks) - MAX_LISTED}")
        lines.append("https://tasks.toorren.net/tasks/by/upcoming")
        return "\n".join(lines)

    task = data.get("task")
    if isinstance(task, dict):
        return f"Vikunja: {event}\n" + task_block(task, data.get("project"))
    return f"Vikunja: {event}"


def send_signal(message):
    body = json.dumps({
        "message": message,
        "number": SIGNAL_SENDER,
        "recipients": [SIGNAL_RECIPIENT],
    }).encode()
    req = urllib.request.Request(
        SIGNAL_API, data=body, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.status


class Handler(BaseHTTPRequestHandler):
    def reply(self, code, text):
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.end_headers()
        self.wfile.write(text.encode())

    def do_GET(self):
        # Gezondheidscheck; geeft niets prijs.
        self.reply(200, "ok\n")

    def do_POST(self):
        length = int(self.headers.get("Content-Length") or 0)
        if length <= 0 or length > MAX_BODY:
            self.reply(413 if length > MAX_BODY else 400, "ongeldige lengte\n")
            return
        raw = self.rfile.read(length)

        expected = hmac.new(SECRET, raw, hashlib.sha256).hexdigest()
        given = self.headers.get("X-Vikunja-Signature", "")
        if not hmac.compare_digest(expected, given):
            log(f"geweigerd: ongeldige handtekening van {self.client_address[0]}")
            self.reply(401, "ongeldige handtekening\n")
            return

        try:
            payload = json.loads(raw)
        except ValueError:
            self.reply(400, "geen JSON\n")
            return

        message = format_message(payload)
        try:
            send_signal(message)
        except (urllib.error.URLError, OSError) as exc:
            # 502 terug zodat de fout ook in Vikunja's log staat, niet alleen hier.
            log(f"Signal-verzending mislukt voor {payload.get('event_name')}: {exc}")
            self.reply(502, "signal-verzending mislukt\n")
            return
        log(f"doorgestuurd: {payload.get('event_name')}")
        self.reply(200, "ok\n")

    def log_message(self, fmt, *args):
        pass  # eigen logregels hierboven; geen access-log per verzoek


def main():
    missing = [n for n, v in (("VIKUNJA_WEBHOOK_SECRET", SECRET),
                              ("SIGNAL_SENDER", SIGNAL_SENDER),
                              ("SIGNAL_RECIPIENT", SIGNAL_RECIPIENT)) if not v]
    if missing:
        log(f"ontbrekende omgevingsvariabelen: {', '.join(missing)}")
        sys.exit(1)
    port = int(os.environ.get("LISTEN_PORT", "8100"))
    log(f"luistert op 127.0.0.1:{port}")
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()


if __name__ == "__main__":
    main()
