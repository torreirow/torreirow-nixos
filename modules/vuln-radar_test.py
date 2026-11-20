#!/usr/bin/env python3
"""Unit tests for vuln-radar matching primitives."""

import importlib.util
import json
import os
import unittest

SPEC = importlib.util.spec_from_file_location(
    "vuln_radar", os.path.join(os.path.dirname(__file__), "vuln-radar.py")
)
VR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VR)


class VersionTests(unittest.TestCase):
    def test_dpkg_epoch(self):
        self.assertTrue(VR.version_lt("1:1.0-1", "1:1.1-1"))

    def test_dpkg_tilde(self):
        self.assertTrue(VR.version_lt("1.0~rc1-1", "1.0-1"))

    def test_dpkg_debian_revision(self):
        self.assertTrue(VR.version_lt("3.5.7-1~deb13u3", "3.5.7-1~deb13u4"))

    def test_kernel(self):
        self.assertTrue(VR.version_lt("6.12.74-2", "6.12.117-1"))

    def test_php(self):
        self.assertTrue(VR.version_lt("8.3.36", "8.3.37"))
        self.assertFalse(VR.version_lt("8.3.37", "8.3.37"))


class MatchTests(unittest.TestCase):
    def test_debian_affected_and_fixed(self):
        data = {
            "openssl": {
                "CVE-2026-1": {
                    "releases": {
                        "trixie": {
                            "fixed_version": "3.5.7-1~deb13u4",
                            "status": "resolved",
                            "urgency": "high",
                        }
                    },
                    "description": "test",
                }
            }
        }
        asset = {"os": "debian", "release": "trixie", "_name": "test"}
        res, unknown = VR.debian_match(asset, "openssl", "3.5.7-1~deb13u3", data, {})
        self.assertEqual(len(res), 1)
        self.assertEqual(unknown, 0)
        res, unknown = VR.debian_match(asset, "openssl", "3.5.7-1~deb13u4", data, {})
        self.assertEqual(res, [])

    def test_php(self):
        php = {"CVE-2026-2": {"8.3": "8.3.37"}}
        asset = {"os": "upstream", "_name": "test"}
        res, _ = VR.upstream_match(asset, "php", "8.3.36", php, {}, {}, {}, source="upstream")
        self.assertEqual([r["cve"] for r in res], ["CVE-2026-2"])

    def test_nginx_130_7_is_fixed(self):
        nginx = {
            "CVE-2026-3": {
                "fixed": "1.30.7",
                "nv_versions": ["1.30.7", "1.31.9"],
                "vuln_min": "0.9.6",
                "vuln_max": "1.31.8",
                "severity": "medium",
            }
        }
        asset = {"os": "upstream", "_name": "test"}
        res, _ = VR.upstream_match(asset, "nginx", "1.30.7", {}, nginx, {}, {})
        self.assertEqual(res, [])
        res, _ = VR.upstream_match(asset, "nginx", "1.30.6", {}, nginx, {}, {})
        self.assertEqual(len(res), 1)

    def test_apache(self):
        apache = {"CVE-2026-4": {"fixed": "2.4.68", "severity": "moderate"}}
        asset = {"os": "upstream", "_name": "test"}
        res, _ = VR.upstream_match(asset, "apache2", "2.4.67", {}, {}, apache, {})
        self.assertEqual(len(res), 1)

    def test_ubuntu_esm_flag(self):
        fixture = {
            "cves": [
                {
                    "id": "CVE-2026-5",
                    "priority": "medium",
                    "packages": [
                        {
                            "name": "nginx",
                            "statuses": [
                                {
                                    "release_codename": "jammy",
                                    "pocket": "esm-infra",
                                    "status": "released",
                                    "description": "1.18.0-6ubuntu14.24",
                                }
                            ],
                        }
                    ],
                }
            ]
        }
        old_fetch = VR.fetch
        VR.fetch = lambda *args, **kwargs: (json.dumps(fixture), None)
        try:
            asset = {"os": "ubuntu", "release": "jammy", "esm": False, "_name": "test"}
            res, unknown, errors = VR.ubuntu_match(asset, "nginx", "1.18.0-6ubuntu14.4", {})
            self.assertEqual(len(res), 1)
            self.assertTrue(res[0]["esm_required"])
            self.assertEqual(errors, [])
        finally:
            VR.fetch = old_fetch

    def test_kev_map(self):
        old_fetch = VR.fetch
        VR.fetch = lambda *args, **kwargs: (
            json.dumps({"vulnerabilities": [{"cveID": "CVE-2020-29583", "dateAdded": "2021-11-03"}]}),
            None,
        )
        try:
            kev, errors = VR.kev_map()
            self.assertIn("CVE-2020-29583", kev)
            self.assertEqual(errors, [])
        finally:
            VR.fetch = old_fetch


class CacheTests(unittest.TestCase):
    def test_second_fetch_uses_cache(self):
        import tempfile

        tmp = tempfile.mkdtemp()
        old_db, old_dir = VR.CACHE_DB, VR.DATA_DIR
        VR.CACHE_DB = os.path.join(tmp, "cache.sqlite")
        VR.DATA_DIR = tmp
        calls = {"n": 0}

        class Resp:
            def __enter__(self):
                return self

            def __exit__(self, *args):
                return False

            def read(self):
                return b"cached-body"

        old_open = VR.urllib.request.urlopen
        def fake_open(*args, **kwargs):
            calls["n"] += 1
            return Resp()

        VR.urllib.request.urlopen = fake_open
        try:
            first, err1 = VR.fetch("https://example.invalid/test", 3600)
            second, err2 = VR.fetch("https://example.invalid/test", 3600)
            self.assertEqual(first, "cached-body")
            self.assertEqual(second, "cached-body")
            self.assertIsNone(err1)
            self.assertIsNone(err2)
            self.assertEqual(calls["n"], 1)
        finally:
            VR.urllib.request.urlopen = old_open
            VR.CACHE_DB, VR.DATA_DIR = old_db, old_dir



if __name__ == "__main__":
    unittest.main()
