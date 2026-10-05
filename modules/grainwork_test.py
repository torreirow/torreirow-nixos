#!/usr/bin/env python3
"""grainwork module-TEST -- toetst de opgebouwde malandro-config, zonder deploy.

    python3 modules/grainwork_test.py

Evalueert malandro met de schakelaars geforceerd: alles uit, alleen fase 1 (cert +
Pocket ID) en alle fasen aan; onafhankelijk van wat hosts/malandro zelf aanzet. De echte gedragstest (nginx, Pocket ID en oauth2-proxy
opgestart) is de VM-test: nix build .#checks.x86_64-linux.grainwork -L

Duurt ongeveer een minuut: één evaluatie, daarna alleen assertions.
"""

import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

# Zelfde aanpak als modules/authelia_test.py: `--apply` op de flake-installable.
APPLY = """
sys:
let
  lib = sys.pkgs.lib;
  # mkForce: malandro zet de schakelaars zelf (uit).
  phase = settings: (sys.extendModules {
    modules = [ { services.grainwork = lib.mapAttrsRecursive (_: lib.mkForce) settings; } ];
  }).config;
  view = c:
    let
      vh = c.services.nginx.virtualHosts;
      site = vh."grainwork.dutchyland.net" or null;
      id = vh."id.dutchyland.net" or null;
      failed = map (a: a.message) (builtins.filter (a: !a.assertion) c.assertions);
    in {
      failedAssertions = builtins.filter (m: builtins.match ".*grainwork.*" m != null) failed;
      cert = c.security.acme.certs."dutchyland.net".domain or null;
      certExtra = c.security.acme.certs."dutchyland.net".extraDomainNames or [ ];
      pocketId = c.services.pocket-id.enable;
      pocketSettings = if c.services.pocket-id.enable then {
        inherit (c.services.pocket-id.settings) APP_URL HOST PORT TRUST_PROXY ANALYTICS_DISABLED;
      } else null;
      pocketCredentials = if c.services.pocket-id.enable
        then builtins.mapAttrs (_: toString) c.services.pocket-id.credentials else null;
      oauth2 = c.services.oauth2-proxy.enable;
      oauth2Settings = if c.services.oauth2-proxy.enable then {
        inherit (c.services.oauth2-proxy) provider oidcIssuerUrl scope redirectURL httpAddress
          setXauthrequest reverseProxy trustedProxyIP extraConfig;
        keyFile = toString c.services.oauth2-proxy.keyFile;
        cookieSecretFile = toString c.services.oauth2-proxy.cookie.secretFile;
        cookieExpire = c.services.oauth2-proxy.cookie.expire;
        cookieSecure = c.services.oauth2-proxy.cookie.secure;
      } else null;
      idVhost = if id == null then null else {
        inherit (id) forceSSL useACMEHost;
        proxyPass = id.locations."/".proxyPass;
        lock = id.locations."/".extraConfig;
      };
      siteVhost = if site == null then null else {
        inherit (site) forceSSL useACMEHost root;
        serverConfig = site.extraConfig;
        locations = builtins.mapAttrs (_: l: { extraConfig = l.extraConfig; proxyPass = l.proxyPass; }) site.locations;
      };
      secretsDir = c.age.secretsDir;
      tmpfiles = builtins.filter (r: builtins.match ".*grainwork.*" r != null) c.systemd.tmpfiles.rules;
    };
in {
  off = view (phase { enable = false; pocketId.enable = false; site.enable = false; });
  phase1 = view (phase { enable = true; pocketId.enable = true; });
  full = view (phase { enable = true; pocketId.enable = true; pocketId.setupLock = false; site.enable = true; });
  siteWithoutPocketId = view (phase { enable = true; pocketId.enable = false; site.enable = true;
    site.clientEnvFile = "/dev/null"; site.cookieSecretFile = "/dev/null"; });
}
"""

RESULTS = []

PUBLIC = ["/welkom/", "~ ^/(css|js|img|fontawesome|webfonts)/", "~ ^/style\\.main\\.[^/]+\\.css$",
          "= /favicon.ico", "= /robots.txt"]


def check(name, condition, detail=""):
    RESULTS.append(bool(condition))
    print(f"  [{'OK  ' if condition else 'FOUT'}] {name}" + (f" -- {detail}" if not condition else ""))


def load():
    out = subprocess.run(
        ["nix", "eval", "--impure", "--json", ".#nixosConfigurations.malandro",
         "--apply", APPLY, "--extra-experimental-features", "nix-command flakes"],
        capture_output=True, text=True, cwd=REPO,
        env={"PATH": "/run/current-system/sw/bin:/usr/bin:/bin",
             "HOME": str(Path.home()), "NIXPKGS_ALLOW_INSECURE": "1"},
    )
    if out.returncode != 0:
        print("nix eval faalde:\n" + out.stderr[-3000:], file=sys.stderr)
        sys.exit(1)
    return json.loads(out.stdout)


def main():
    r = load()

    print("alle schakelaars uit")
    cur = r["off"]
    check("geen dutchyland-cert", cur["cert"] is None, str(cur["cert"]))
    check("geen Pocket ID", not cur["pocketId"])
    check("geen oauth2-proxy", not cur["oauth2"])
    check("geen vhosts", cur["idVhost"] is None and cur["siteVhost"] is None)

    print("fase 1: cert + Pocket ID met setup-slot")
    p1 = r["phase1"]
    check("wildcard-cert", p1["cert"] == "*.dutchyland.net" and p1["certExtra"] == ["dutchyland.net"],
          f"{p1['cert']} {p1['certExtra']}")
    check("Pocket ID aan, site uit", p1["pocketId"] and not p1["oauth2"] and p1["siteVhost"] is None)
    s = p1["pocketSettings"]
    check("APP_URL https://id.dutchyland.net", s["APP_URL"] == "https://id.dutchyland.net", s["APP_URL"])
    check("alleen loopback op 8098", s["HOST"] == "127.0.0.1" and s["PORT"] == 8098, f"{s['HOST']}:{s['PORT']}")
    check("achter proxy, geen analytics", s["TRUST_PROXY"] and s["ANALYTICS_DISABLED"])
    creds = p1["pocketCredentials"]
    sd = p1["secretsDir"]
    check("DB en encryption key uit agenix",
          creds.get("DB_CONNECTION_STRING") == f"{sd}/grainwork-pocket-id-db"
          and creds.get("ENCRYPTION_KEY") == f"{sd}/grainwork-pocket-id-encryption-key", str(creds))
    idv = p1["idVhost"]
    check("id-vhost met TLS", idv["forceSSL"] and idv["useACMEHost"] == "dutchyland.net", str(idv))
    check("proxy naar Pocket ID", idv["proxyPass"] == "http://127.0.0.1:8098", idv["proxyPass"])
    lock = idv["lock"]
    check("setup-slot: LAN, WireGuard en loopback toegestaan, rest geweigerd",
          all(f"allow {n};" in lock for n in ("127.0.0.1", "192.168.2.0/24", "10.8.0.0/24"))
          and lock.rstrip().endswith("deny all;"), lock)
    check("geen fouten in assertions", not p1["failedAssertions"], str(p1["failedAssertions"]))

    print("alle fasen aan")
    full = r["full"]
    check("setup-slot uit na de setup", full["idVhost"]["lock"].strip() == "", full["idVhost"]["lock"])
    o = full["oauth2Settings"]
    check("oauth2-proxy aan", full["oauth2"])
    check("OIDC naar Pocket ID", o["provider"] == "oidc" and o["oidcIssuerUrl"] == "https://id.dutchyland.net",
          f"{o['provider']} {o['oidcIssuerUrl']}")
    check("scope met groups", o["scope"] == "openid email profile groups", o["scope"])
    check("PKCE S256", o["extraConfig"].get("code-challenge-method") == "S256", str(o["extraConfig"]))
    check("callback op de site", o["redirectURL"] == "https://grainwork.dutchyland.net/oauth2/callback",
          o["redirectURL"])
    check("loopback 8099", o["httpAddress"] == "http://127.0.0.1:8099", o["httpAddress"])
    check("client en cookie uit agenix",
          o["keyFile"] == f"{full['secretsDir']}/grainwork-oauth2-proxy-client"
          and o["cookieSecretFile"] == f"{full['secretsDir']}/grainwork-oauth2-proxy-cookie",
          f"{o['keyFile']} {o['cookieSecretFile']}")
    check("cookie 30 dagen en secure", o["cookieExpire"] == "720h0m0s" and o["cookieSecure"],
          f"{o['cookieExpire']} {o['cookieSecure']}")
    check("vertrouwt alleen nginx op loopback", o["reverseProxy"] and o["trustedProxyIP"] == ["127.0.0.1"])

    site = full["siteVhost"]
    check("site-vhost met TLS en webroot", site["forceSSL"] and site["useACMEHost"] == "dutchyland.net"
          and site["root"] == "/var/www/grainwork", str({k: site[k] for k in ("forceSSL", "useACMEHost", "root")}))
    check("auth_request op de hele vhost", "auth_request /oauth2/auth;" in site["serverConfig"], site["serverConfig"])
    auth = site["locations"].get("= /oauth2/auth", {})
    check("alleen groep grainwork", "allowed_groups=grainwork" in (auth.get("proxyPass") or ""), str(auth))
    for path in PUBLIC:
        loc = site["locations"].get(path)
        check(f"publiek: {path}", loc is not None and "auth_request off;" in (loc["extraConfig"] or ""), str(loc))
    root_loc = site["locations"]["/"]["extraConfig"] or ""
    check("'/' is NIET publiek", "auth_request off" not in root_loc, root_loc)
    check("webroot geborgd", full["tmpfiles"] == ["d /var/www/grainwork 0755 nginx nginx -"], str(full["tmpfiles"]))
    check("geen fouten in assertions", not full["failedAssertions"], str(full["failedAssertions"]))

    print("bewaking")
    check("site zonder Pocket ID wordt geweigerd",
          any("vereist services.grainwork.pocketId" in m for m in r["siteWithoutPocketId"]["failedAssertions"]),
          str(r["siteWithoutPocketId"]["failedAssertions"]))

    print()
    if all(RESULTS):
        print(f"alle {len(RESULTS)} tests geslaagd")
        return 0
    print(f"{RESULTS.count(False)} van de {len(RESULTS)} tests gefaald")
    return 1


if __name__ == "__main__":
    sys.exit(main())
