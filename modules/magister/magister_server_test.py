#!/usr/bin/env python3
"""magister_server unit-TEST -- sessiestatus (auth_time / last_refresh), footer en heartbeat.

    nix-shell -p 'python3.withPackages (p: [p.python-dateutil p.beautifulsoup4])' \
        --run 'python3 modules/magister/magister_server_test.py'

Raakt Magister niet: het token-endpoint wordt gemockt en alles draait in een tijdelijke map.
"""

import base64
import importlib
import json
import logging
import os
import sys
import tempfile
import time
import unittest
from datetime import datetime
from pathlib import Path
from unittest import mock

# magister_server roept bij import setup_logging() aan, en dat opent
# /var/log/magister/magister.log. Daar heeft een normale gebruiker geen schrijfrechten.
with mock.patch.object(logging, "FileHandler", lambda *a, **k: logging.NullHandler()):
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    ms = importlib.import_module("magister_server")

AUTH_TIME = 1788248951  # 2026-09-01 09:49:11 +02:00


def make_jwt(payload):
    """Ongetekend JWT: alleen het payload-deel doet ertoe."""
    def b64(obj):
        raw = json.dumps(obj).encode()
        return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()
    return f"{b64({'alg': 'RS256'})}.{b64(payload)}.c2lnbmF0dXJl"


class InTempDir(unittest.TestCase):
    def setUp(self):
        self._old_cwd = os.getcwd()
        self._tmp = tempfile.TemporaryDirectory()
        os.chdir(self._tmp.name)

    def tearDown(self):
        os.chdir(self._old_cwd)
        self._tmp.cleanup()


class SessionStatusTest(unittest.TestCase):
    def test_auth_time_uit_jwt(self):
        tok = {"access_token": make_jwt({"auth_time": AUTH_TIME, "exp": 1}), "last_refresh": 123.0}
        st = ms.session_status(tok, token_mtime=999.0)
        self.assertEqual(st["auth_time"], AUTH_TIME)
        self.assertEqual(st["last_refresh"], 123.0)

    def test_kapot_jwt_geeft_none(self):
        for bad in ["", "geen-jwt", "a.b.c", "a.!!!.c", None, 42]:
            st = ms.session_status({"access_token": bad}, token_mtime=None)
            self.assertIsNone(st["auth_time"], bad)

    def test_ontbrekende_of_niet_numerieke_claim(self):
        for payload in [{}, {"auth_time": "gisteren"}, {"auth_time": True}, ["lijst"]]:
            st = ms.session_status({"access_token": make_jwt(payload)}, token_mtime=None)
            self.assertIsNone(st["auth_time"], payload)

    def test_mtime_fallback_voor_last_refresh(self):
        st = ms.session_status({"access_token": make_jwt({"auth_time": AUTH_TIME})}, token_mtime=555.0)
        self.assertEqual(st["last_refresh"], 555.0)

    def test_alles_onbekend(self):
        self.assertEqual(ms.session_status({}, token_mtime=None),
                         {"auth_time": None, "last_refresh": None})
        self.assertEqual(ms.session_status(None, token_mtime=None),
                         {"auth_time": None, "last_refresh": None})


class FakeResponse:
    def __init__(self, body):
        self._body = json.dumps(body).encode()

    def read(self):
        return self._body

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


class RefreshTest(InTempDir):
    def test_refresh_schrijft_last_refresh_en_roteert(self):
        Path("token.json").write_text(json.dumps({"refresh_token": "oud"}))
        new_access = make_jwt({"auth_time": AUTH_TIME})
        resp = FakeResponse({"access_token": new_access, "refresh_token": "nieuw", "expires_in": 3600})
        client = ms.MagisterServerClient()
        before = time.time()
        with mock.patch.object(ms.urllib.request, "urlopen", return_value=resp):
            self.assertEqual(client._refresh_access_token(), new_access)
        saved = json.loads(Path("token.json").read_text())
        self.assertEqual(saved["refresh_token"], "nieuw")
        self.assertGreaterEqual(saved["last_refresh"], before)
        self.assertLessEqual(saved["last_refresh"], time.time())
        self.assertEqual(oct(os.stat("token.json").st_mode & 0o777), "0o600")

    def test_client_session_status_leest_bestand(self):
        Path("token.json").write_text(json.dumps({"access_token": make_jwt({"auth_time": AUTH_TIME})}))
        os.utime("token.json", (777.0, 777.0))
        st = ms.MagisterServerClient().session_status()
        self.assertEqual(st, {"auth_time": AUTH_TIME, "last_refresh": 777.0})

    def test_client_session_status_zonder_bestand(self):
        st = ms.MagisterServerClient().session_status()
        self.assertEqual(st, {"auth_time": None, "last_refresh": None})


class FooterTest(InTempDir):
    def _html(self, session):
        Path("magister_test.ics").write_text("BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n")
        self.assertTrue(ms.generate_index_html(session=session))
        return Path("index.html").read_text(encoding="utf-8")

    def test_footer_met_status(self):
        last = time.time() - 120
        html = self._html({"auth_time": time.time() - 44 * 86400 - 60, "last_refresh": last})
        self.assertIn("<strong>Laatste update:</strong>", html)
        self.assertIn("<strong>Ingelogd sinds:</strong>", html)
        self.assertIn("(44 dagen)", html)
        self.assertIn(f"<strong>Laatste refresh:</strong> {datetime.fromtimestamp(last):%Y-%m-%d %H:%M}", html)
        self.assertIn("<strong>Token-verloop:</strong> onbekend (Magister geeft dit niet prijs)", html)

    def test_footer_onbekend(self):
        html = self._html({"auth_time": None, "last_refresh": None})
        self.assertIn("<strong>Ingelogd sinds:</strong> onbekend", html)
        self.assertIn("<strong>Laatste refresh:</strong> onbekend", html)

    def test_footer_zonder_session_argument(self):
        html = self._html(None)
        self.assertIn("<strong>Ingelogd sinds:</strong> onbekend", html)

    def test_een_dag_enkelvoud(self):
        html = self._html({"auth_time": time.time() - 86400 - 60, "last_refresh": time.time()})
        self.assertIn("(1 dag)", html)


class HeartbeatTest(InTempDir):
    def _prom(self, session):
        path = os.path.join(os.getcwd(), "magister_heartbeat.prom")
        with mock.patch.object(ms, "HEARTBEAT_FILE", path):
            self.assertTrue(ms.write_heartbeat(session))
        return Path(path).read_text()

    def test_beide_metrics(self):
        prom = self._prom({"auth_time": AUTH_TIME, "last_refresh": 1792070741.5})
        self.assertIn("magister_sync_heartbeat_timestamp ", prom)
        self.assertIn(f"magister_auth_time_seconds {AUTH_TIME}\n", prom)
        self.assertIn("magister_last_refresh_seconds 1792070741.5\n", prom)
        self.assertIn("# TYPE magister_auth_time_seconds gauge", prom)
        self.assertIn("# TYPE magister_last_refresh_seconds gauge", prom)

    def test_onbekend_wordt_weggelaten(self):
        prom = self._prom({"auth_time": None, "last_refresh": 5.0})
        self.assertNotIn("magister_auth_time_seconds", prom)
        self.assertIn("magister_last_refresh_seconds 5.0\n", prom)
        self.assertIn("magister_sync_heartbeat_timestamp ", prom)

    def test_zonder_session_alleen_heartbeat(self):
        prom = self._prom(None)
        self.assertIn("magister_sync_heartbeat_timestamp ", prom)
        self.assertNotIn("magister_auth_time_seconds", prom)
        self.assertNotIn("magister_last_refresh_seconds", prom)


if __name__ == "__main__":
    unittest.main(verbosity=2)
