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
sys:
let
  cfg = sys.config;
  mcp = cfg.services.linny-mcp;
  unit = n: cfg.systemd.services.${n};

  # De publieke vhost staat standaard uit; om hem toch te kunnen toetsen wordt
  # de configuratie één keer uitgebreid met publicEndpoint = true.
  pub = (sys.extendModules {
    modules = [ { services.linny-mcp-host.publicEndpoint = true; } ];
  }).config;
  vhost = pub.services.nginx.virtualHosts."%s";

  # En nog een keer mét de OIDC-laag aan. Apart nodig: `//` op vhost-niveau is
  # een ondiepe merge, dus een fout daarin is alleen zichtbaar als oidc AAN staat.
  oidcCfg = (sys.extendModules {
    modules = [ { services.linny-mcp-host = { publicEndpoint = true; oidc.enable = true; }; } ];
  }).config;
  oidcVhost = oidcCfg.services.nginx.virtualHosts."%s";
in {
  oidcLocaties   = builtins.attrNames oidcVhost.locations;
  oidcRootExtra  = oidcVhost.locations."/".extraConfig;
  oidcAuthzPass  = oidcVhost.locations."/authz-mcp".proxyPass;
  oidcAuthzExtra = oidcVhost.locations."/authz-mcp".extraConfig;
  oidcChallenge  = oidcVhost.locations."@mcp_unauthorized".extraConfig;
  oidcWellKnown  = oidcVhost.locations."= /.well-known/oauth-protected-resource".extraConfig;
  oidcSecretPad  = toString oidcCfg.age.secrets.linny-mcp-nginx-token.path;
  vhostAanwezigStandaard = builtins.hasAttr "%s" cfg.services.nginx.virtualHosts;
  oidcAanStandaard       = cfg.services.linny-mcp-host.oidc.enable;
  listenAddress = mcp.listenAddress;
  port          = mcp.port;
  corpusPath    = toString mcp.corpusPath;
  stateDir      = toString mcp.stateDir;
  tokensFile    = toString mcp.tokensFile;
  quarantine    = mcp.quarantine;
  readOnly      = mcp.readOnly;

  restartTriggers = map toString (unit "linny-mcp").restartTriggers;

  # De secrets liggen onder /run/keys (root:keys 0750). Zonder de groep `keys`
  # kan de linny-mcp-user de map niet traverseren en faalt élke unit die een
  # secret leest -- ook al is het bestand zelf van hem.
  keysGroups = builtins.listToAttrs (map (n: {
    name = n;
    value = (unit n).serviceConfig.SupplementaryGroups or [ ];
  }) [ "linny-mcp" "linny-mcp-clone" "linny-mcp-git-sync" ]);

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
  vhostRecProxy  = vhost.locations."/".recommendedProxySettings;
  vhostLocations = builtins.attrNames vhost.locations;
  vhostForceSSL  = vhost.forceSSL;
  vhostACME      = vhost.useACMEHost;

  # Bewijs dat de Hugo-build een ANDERE werkmap heeft.
  linnyWebStateDir = toString cfg.services.linny-web.stateDir;
}
""" % (DOMAIN, DOMAIN, DOMAIN)


def load():
    out = subprocess.run(
        ["nix", "eval", "--impure", "--json",
         ".#nixosConfigurations.malandro", "--apply", APPLY,
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

    for unit_name, groups in sorted(c["keysGroups"].items()):
        check(f"{unit_name} zit in de groep keys",
              "keys" in groups,
              f"SupplementaryGroups={groups}")

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
    # De vhost is opt-in. Op malandro staat hij AAN sinds de OIDC-laag er is;
    # zonder die laag hoort hij uit te staan, want dan is er geen slot.
    check("publieke vhost alleen samen met de OIDC-laag",
          c["vhostAanwezigStandaard"] == c["oidcAanStandaard"],
          f'vhost={c["vhostAanwezigStandaard"]} oidc={c["oidcAanStandaard"]}')
    # Authelia mag ervoor staan, maar NOOIT in zijn redirect-vorm: een MCP-client
    # stuurt alleen een bearer-token en volgt geen loginredirect naar HTML.
    # Het legacy /api/verify-endpoint en de /authelia-location horen bij die vorm.
    check("geen redirect-gebaseerde Authelia (wel bearer-authz)",
          "/authelia" not in c["vhostLocations"]
          and "/api/verify" not in c["vhostExtra"],
          f'locations={c["vhostLocations"]}')
    check("Host wordt op loopback gezet (DNS-rebinding-check van de SDK)",
          "proxy_set_header Host localhost;" in c["vhostExtra"],
          c["vhostExtra"])
    check("aanbevolen proxy-headers uit (anders dubbele Host)",
          c["vhostRecProxy"] is False,
          str(c["vhostRecProxy"]))
    check("X-Forwarded-For blijft gezet",
          "X-Forwarded-For" in c["vhostExtra"], c["vhostExtra"])
    print("oidc-laag")
    for loc in ["/", "/authz-mcp", "@mcp_unauthorized",
                "= /.well-known/oauth-protected-resource"]:
        check(f"location {loc} bestaat met oidc aan",
              loc in c["oidcLocaties"], str(c["oidcLocaties"]))
    check("de proxy naar linny-mcp overleeft de merge",
          "proxy_set_header Host localhost;" in c["oidcRootExtra"],
          c["oidcRootExtra"][:200])
    # Alleen directives vergelijken: het commentaar hierboven noemt "include"
    # ook, en dat staat er juist vóór -- een naïeve index() faalt daarop.
    directives = [ln.strip() for ln in c["oidcRootExtra"].splitlines()
                  if ln.strip() and not ln.strip().startswith("#")]
    volgorde = [i for i, d in enumerate(directives)
                if d.startswith("auth_request") or d.startswith("include")]
    check("auth_request staat vóór de token-include",
          len(volgorde) == 2
          and directives[volgorde[0]].startswith("auth_request"),
          str([directives[i] for i in volgorde]))
    check("token-include is een wildcard (nginx -t draait zonder /run/agenix)",
          "include /run/agenix/linny-mcp-nginx-token*;" in c["oidcRootExtra"],
          c["oidcRootExtra"][-300:])
    check("authz gaat naar Authelia's mcp-endpoint",
          "/api/authz/mcp" in c["oidcAuthzPass"], c["oidcAuthzPass"])
    check("Authelia's Basic-uitdaging wordt onderdrukt",
          "proxy_hide_header WWW-Authenticate;" in c["oidcAuthzExtra"],
          c["oidcAuthzExtra"][:200])
    check("401 daagt uit met Bearer, niet Basic",
          "WWW-Authenticate" in c["oidcChallenge"]
          and "Bearer resource_metadata=" in c["oidcChallenge"],
          c["oidcChallenge"][:200])
    check("well-known wijst de authorization server aan",
          "auth.toorren.net" in c["oidcWellKnown"], c["oidcWellKnown"][:200])
    check("well-known declareert de scope die Authelia eist",
          "authelia.bearer.authz" in c["oidcWellKnown"], c["oidcWellKnown"][:200])
    check("geen tokenliteral in de nginx-config",
          "Bearer " not in c["oidcRootExtra"], c["oidcRootExtra"][-200:])
    print("vhost")
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
