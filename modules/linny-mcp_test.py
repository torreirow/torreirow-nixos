#!/usr/bin/env python3
"""
linny-mcp module-TEST -- draait zonder deploy, zonder netwerk naar de server.

Toetst de *opgebouwde* NixOS-config van malandro, niet alleen of hij evalueert.
Dat onderscheid is hier het hele punt: de eisen uit
openspec/specs/linny-mcp-hosting gaan over wát er in de config staat -- welk
adres er gebonden wordt, welke werkmap het corpus is, en dat er géén Authelia
voor de MCP-vhost zit.

    python3 modules/linny-mcp_test.py

Duurt een halve minuut: er wordt één keer geëvalueerd, daarna alleen geassert.
"""

import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DOMAIN = "linny-mcp.toorren.net"

# Eén evaluatie levert alles; nix eval is het dure deel.
#
# Bewust `--apply` op de flake-installable in plaats van `builtins.getFlake` op
# het pad: dat laatste leest de hele werkmap en struikelt over een socket in de
# repo-root ("unsupported type"). Via de installable ziet nix alleen de
# git-getrackte bron.
APPLY = """
cfg:
let
  mcp = cfg.services.linny-mcp;
  vhost = cfg.services.nginx.virtualHosts."%s";
  unit = n: cfg.systemd.services.${n};
in {
  listenAddress = mcp.listenAddress;
  port          = mcp.port;
  corpusPath    = toString mcp.corpusPath;
  stateDir      = toString mcp.stateDir;
  tokensFile    = toString mcp.tokensFile;
  quarantine    = mcp.quarantine;
  readOnly      = mcp.readOnly;

  restartTriggers = map toString (unit "linny-mcp").restartTriggers;

  indexPre    = (unit "linny-mcp-index").serviceConfig.ExecStartPre;
  indexStart  = (unit "linny-mcp-index").serviceConfig.ExecStart;
  indexBefore = (unit "linny-mcp-index").before;
  indexAfter  = (unit "linny-mcp-index").after;

  cloneBefore = (unit "linny-mcp-clone").before;
  syncScript  = (unit "linny-mcp-git-sync").serviceConfig.ExecStart;
  syncTimer   = cfg.systemd.timers.linny-mcp-git-sync.timerConfig.OnUnitActiveSec;

  tmpfiles = builtins.filter (r: builtins.match ".*linny-mcp.*" r != null) cfg.systemd.tmpfiles.rules;

  vhostProxy     = vhost.locations."/".proxyPass;
  vhostExtra     = vhost.locations."/".extraConfig;
  vhostLocations = builtins.attrNames vhost.locations;
  vhostForceSSL  = vhost.forceSSL;
  vhostACME      = vhost.useACMEHost;

  # Bewijs dat de Hugo-build een ANDERE werkmap heeft.
  linnyWebStateDir = toString cfg.services.linny-web.stateDir;
}
""" % DOMAIN


def load():
    out = subprocess.run(
        ["nix", "eval", "--impure", "--json",
         ".#nixosConfigurations.malandro.config", "--apply", APPLY,
         "--extra-experimental-features", "nix-command flakes"],
        capture_output=True, text=True, cwd=REPO,
        env={"PATH": "/run/current-system/sw/bin:/usr/bin:/bin",
             "HOME": str(Path.home()), "NIXPKGS_ALLOW_INSECURE": "1"},
    )
    if out.returncode != 0:
        print("nix eval faalde:\n" + out.stderr[-2000:], file=sys.stderr)
        sys.exit(1)
    return json.loads(out.stdout)


RESULTS = []


def check(name, condition, detail=""):
    ok = bool(condition)
    RESULTS.append(ok)
    status = "OK  " if ok else "FOUT"
    print(f"  [{status}] {name}" + (f" -- {detail}" if detail and not ok else ""))
    return ok


def main():
    c = load()
    print("bind en corpus")
    check("bindt loopback, niet publiek", c["listenAddress"] == "127.0.0.1", c["listenAddress"])
    check("bindt niet 0.0.0.0", c["listenAddress"] != "0.0.0.0")
    check("poort uit PORTS.md", c["port"] == 8096, str(c["port"]))
    check("corpus buiten /home", c["corpusPath"].startswith("/var/lib"), c["corpusPath"])
    check("state buiten /home", c["stateDir"].startswith("/var/lib"), c["stateDir"])

    print("scheiding van de Hugo-build")
    # De kern: linny-web-build doet `reset --hard` + `clean -fdx` op ZIJN checkout.
    # Delen ze een werkmap, dan sneuvelen ongepushte agent-notities stil.
    check("corpus is NIET de linny-web-werkmap",
          not c["corpusPath"].startswith(c["linnyWebStateDir"]),
          f'{c["corpusPath"]} vs {c["linnyWebStateDir"]}')
    check("corpus is niet de torrlinny-checkout",
          c["corpusPath"] != "/var/lib/torrlinny/checkout", c["corpusPath"])
    check("index staat buiten het corpus",
          not c["stateDir"].startswith(c["corpusPath"]),
          f'{c["stateDir"]} in {c["corpusPath"]}')

    print("schrijfgrens")
    check("quarantine staat aan", c["quarantine"] is True)
    check("corpus is schrijfbaar", c["readOnly"] is False)

    print("secrets")
    check("tokensFile komt uit agenix", c["tokensFile"].startswith("/run/agenix/"), c["tokensFile"])
    check("geen tokenwaarde in de optie", ".age" not in c["tokensFile"])
    # De server leest het tokenbestand eenmalig; zonder trigger blijven oude
    # scopes na een hercodering in geheugen staan.
    check("restartTrigger op het tokens-secret",
          any("linny-mcp-tokens" in t for t in c["restartTriggers"]),
          str(c["restartTriggers"]))

    print("indexer")
    # `serve` bouwt zelf nooit een index; zonder deze unit zien clients nul docs.
    check("volledige build als ExecStartPre", "lindexer" in c["indexPre"] and " build " in c["indexPre"],
          c["indexPre"])
    check("watch als ExecStart", "lindexer" in c["indexStart"] and " watch " in c["indexStart"],
          c["indexStart"])
    check("index draait vóór de server", "linny-mcp.service" in c["indexBefore"], str(c["indexBefore"]))
    check("index draait na de clone", "linny-mcp-clone.service" in c["indexAfter"], str(c["indexAfter"]))
    check("index schrijft naar de state-dir", c["stateDir"] in c["indexStart"], c["indexStart"])
    check("index schrijft niet in het corpus",
          f'-index {c["corpusPath"]}' not in c["indexStart"], c["indexStart"])

    print("corpus-sync")
    check("clone draait vóór de server", "linny-mcp.service" in c["cloneBefore"], str(c["cloneBefore"]))
    check("sync-timer is gezet", c["syncTimer"] == "30s", str(c["syncTimer"]))
    check("git-sync wordt aangeroepen", "git-sync" in c["syncScript"], c["syncScript"][:80])

    print("tmpfiles")
    # ReadWritePaths bind-mount deze paden; ontbreken ze, dan faalt de unit met
    # 226/NAMESPACE nog vóór exec.
    rules = " ".join(c["tmpfiles"])
    check("corpus wordt aangemaakt", c["corpusPath"] in rules, rules)
    check("state wordt aangemaakt", c["stateDir"] in rules, rules)

    print("vhost")
    check("proxyt naar de lokale poort", f':{c["port"]}' in c["vhostProxy"], c["vhostProxy"])
    check("TLS afgedwongen", c["vhostForceSSL"] is True)
    check("gebruikt het wildcard-cert", c["vhostACME"] == "toorren.net", str(c["vhostACME"]))
    # Een MCP-client stuurt alleen een bearer-token en volgt geen loginredirect,
    # dus Authelia zou het eindpunt onbruikbaar maken.
    check("GEEN Authelia op deze vhost",
          "auth_request" not in c["vhostExtra"] and "/authelia" not in c["vhostLocations"],
          f'locations={c["vhostLocations"]}')
    check("SSE: buffering uit", "proxy_buffering off" in c["vhostExtra"])
    check("SSE: lange read-timeout", "proxy_read_timeout 3600s" in c["vhostExtra"])

    print()
    if all(RESULTS):
        print(f"alle {len(RESULTS)} tests geslaagd")
        return 0
    print(f"ER ZIJN {RESULTS.count(False)} VAN {len(RESULTS)} TESTS GEFAALD", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
