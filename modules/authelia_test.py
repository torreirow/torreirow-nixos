#!/usr/bin/env python3
"""authelia module-TEST -- toetst de opgebouwde malandro-config, zonder deploy.

    python3 modules/authelia_test.py

Dit bestand beschermt álle vhosts: Nextcloud, Grafana, Home Assistant, Wallos en
de MCP-connector hangen er allemaal aan. Op 2026-09-25 verdween `/api/verify`
doordat `server.endpoints.authz` de standaardset VERVANGT in plaats van aanvult,
en gaven ze vier minuten lang een 500. Die controle staat er daarom in.

Duurt een halve minuut: één evaluatie, daarna alleen assertions.
"""

import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

# Zelfde aanpak als modules/linny-mcp_test.py: `--apply` op de flake-installable
# in plaats van `builtins.getFlake` op het pad, omdat dat laatste de hele werkmap
# leest en struikelt over een socket in de repo-root.
APPLY = """
sys:
let
  oidc = sys.config.services.authelia.instances.main.settings.identity_providers.oidc;
  session = sys.config.services.authelia.instances.main.settings.session;
  client = id: builtins.head (builtins.filter (c: c.client_id == id) oidc.clients);
  connector = client "claude-connector";
  wallos = client "wallos";
in {
  clientIds = map (c: c.client_id) oidc.clients;

  connectorLifespan   = connector.lifespan or null;
  connectorConsent    = connector.consent_mode or null;
  connectorConsentDur = connector.pre_configured_consent_duration or null;
  connectorScopes     = connector.scopes;
  connectorAudience   = connector.audience or [ ];

  wallosLifespan = wallos.lifespan or null;
  wallosConsent  = wallos.consent_mode or null;

  lifespanNames = builtins.attrNames (oidc.lifespans.custom or { });
  connectorAccess  = oidc.lifespans.custom.connector.access_token or null;
  connectorRefresh = oidc.lifespans.custom.connector.refresh_token or null;

  authzEndpoints = builtins.attrNames
    (sys.config.services.authelia.instances.main.settings.server.endpoints.authz or { });

  cookieInactivity = (builtins.head session.cookies).inactivity;
  cookieExpiration = (builtins.head session.cookies).expiration;
}
"""

RESULTS = []


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
        print("nix eval faalde:\n" + out.stderr[-2000:], file=sys.stderr)
        sys.exit(1)
    return json.loads(out.stdout)


def main():
    c = load()

    print("connector-client")
    check("verwijst naar het lifespan-profiel",
          c["connectorLifespan"] == "connector", str(c["connectorLifespan"]))
    check("toestemming wordt onthouden",
          c["connectorConsent"] == "pre-configured", str(c["connectorConsent"]))
    check("met een duur (anders valt pre-configured terug op explicit)",
          bool(c["connectorConsentDur"]), str(c["connectorConsentDur"]))
    # De scope authelia.bearer.authz trekt verplicht PAR mee, en Claude doet dat
    # niet. Zie de gearchiveerde change add-linny-mcp-oidc.
    check("gebruikt NIET authelia.bearer.authz",
          "authelia.bearer.authz" not in c["connectorScopes"], str(c["connectorScopes"]))
    check("offline_access aanwezig (anders geen refresh-token)",
          "offline_access" in c["connectorScopes"], str(c["connectorScopes"]))
    # Claude stuurt resource= mee (RFC 8707); zonder audience weigert Authelia.
    check("audience gewhitelist",
          any("linny-mcp" in a for a in c["connectorAudience"]), str(c["connectorAudience"]))

    print("levensduren")
    check("profiel `connector` bestaat",
          "connector" in c["lifespanNames"], str(c["lifespanNames"]))
    # Dit is de belangrijkste: alleen de refresh-token mag verlengd zijn. De
    # access-token gaat bij elk verzoek over de lijn.
    check("access-token blijft 1h",
          c["connectorAccess"] == "1h", str(c["connectorAccess"]))
    check("refresh-token is verlengd voorbij de standaard van 90m",
          c["connectorRefresh"] not in (None, "90m", "1h30m"), str(c["connectorRefresh"]))

    print("isolatie")
    check("wallos erft het profiel NIET",
          c["wallosLifespan"] is None, str(c["wallosLifespan"]))
    check("wallos houdt zijn eigen toestemming",
          c["wallosConsent"] == "pre-configured", str(c["wallosConsent"]))
    check("de sessie-cookie is ongemoeid (inactivity)",
          c["cookieInactivity"] == "5m", str(c["cookieInactivity"]))
    check("de sessie-cookie is ongemoeid (expiration)",
          c["cookieExpiration"] == "1h", str(c["cookieExpiration"]))

    print("authz-endpoints")
    # server.endpoints.authz VERVANGT de standaardset. Zonder `legacy` geeft
    # /api/verify een 404 en vallen alle bestaande vhosts om.
    check("legacy bestaat nog (anders vallen alle vhosts om)",
          "legacy" in c["authzEndpoints"], str(c["authzEndpoints"]))
    check("mcp-endpoint bestaat",
          "mcp" in c["authzEndpoints"], str(c["authzEndpoints"]))

    print()
    if all(RESULTS):
        print(f"alle {len(RESULTS)} tests geslaagd")
        return 0
    print(f"{RESULTS.count(False)} van de {len(RESULTS)} tests gefaald")
    return 1


if __name__ == "__main__":
    sys.exit(main())
