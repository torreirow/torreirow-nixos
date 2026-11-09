{ config, lib, pkgs, ... }:

# AI-crawlers weren van de publieke statische sites, zonder gewone zoekmachines te raken.
#
#   ai-blocklist.timer (dagelijks) ─▶ update-ai-blocklist.py ─▶ /var/lib/ai-blocklist/
#     ai-bots-map.conf    map $http_user_agent $ai_bot  (include in commonHttpConfig)
#     robots/<vhost>.txt  bestaande robots.txt uit de webroot + Disallow per AI-bot
#
# Per site in services.aiBlocklist.sites:
#   - location = /robots.txt serveert het gegenereerde bestand (ook voor AI-bots bereikbaar)
#   - if ($ai_bot) { return 403; } in "/" en de opgegeven extraLocations; bewust niet op
#     server-niveau, anders zou robots.txt ook geblokkeerd worden
#   - noindex = true: ook een `User-agent: *`/`Disallow: /` als de site die nog niet
#     heeft, plus X-Robots-Tag: noindex
#   - allowAgents: bots die op déze site wel mogen (bijv. facebookexternalhit voor
#     link-previews). De site toetst dan $ai_bot_<vhost>, een map die $ai_bot overneemt
#     maar deze namen op 0 zet; in robots.txt krijgen ze geen Disallow.
#
# Een nieuwe robots.txt in een webroot (release.sh) wordt via ai-blocklist.path direct
# opgepikt. Zonder netwerk bij de eerste boot dekt een startlijst uit de store de map af.
# Bronlijst: https://github.com/ai-robots-txt/ai.robots.txt

let
  cfg = config.services.aiBlocklist;
  stateDir = "/var/lib/ai-blocklist";
  vhosts = config.services.nginx.virtualHosts;

  sitesJson = pkgs.writeText "ai-blocklist-sites.json" (builtins.toJSON (lib.mapAttrsToList
    (vhost: site: {
      inherit vhost;
      inherit (site) noindex;
      webroot = toString vhosts.${vhost}.root;
      sitemap = if site.sitemap then "https://${vhost}/sitemap.xml" else null;
      inherit (site) allowAgents;
    })
    cfg.sites));

  # Startlijst tot de eerste geslaagde run; daarna overschreven door de actuele lijst.
  seedMap = pkgs.writeText "ai-bots-map.conf" ''
    map $http_user_agent $ai_bot {
        default 0;
        "~*\b(?:GPTBot|ChatGPT-User|OAI-SearchBot|ClaudeBot|Claude-Web|Claude-User|Claude-SearchBot|anthropic-ai|PerplexityBot|Perplexity-User|CCBot|Bytespider|Amazonbot|meta-externalagent|FacebookBot|Google-Extended|GoogleOther|Applebot-Extended|cohere-ai|Diffbot|ImagesiftBot|Omgilibot|YouBot|DuckAssistBot|MistralAI-User|PetalBot|Timpibot)\b" 1;
    }
  '';

  updater = pkgs.writeShellScript "update-ai-blocklist" ''
    exec ${pkgs.python3}/bin/python3 ${./update-ai-blocklist.py}
  '';

  # Variabele die een site toetst: de gedeelde $ai_bot, of een afgeleide als de site
  # bots vrijgeeft (nginx kent geen && in if, dus de uitzondering moet in de map).
  botVar = vhost: site:
    if site.allowAgents == [ ] then "$ai_bot"
    else "$ai_bot_${lib.replaceStrings [ "." "-" ] [ "_" "_" ] (lib.toLower vhost)}";

  allowMap = vhost: site: ''
    map $http_user_agent ${botVar vhost site} {
        default $ai_bot;
        "~*\b(?:${lib.concatMapStringsSep "|" lib.escapeRegex site.allowAgents})\b" 0;
    }
  '';

  blockIf = vhost: site: ''
    if (${botVar vhost site}) { return 403; }
  '';
in
{
  options.services.aiBlocklist.sites = lib.mkOption {
    default = { };
    description = "Nginx-vhosts (met root in een webroot) waar AI-crawlers geweerd worden.";
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        sitemap = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Sitemap-regel (https://<vhost>/sitemap.xml) toevoegen als robots.txt die nog niet heeft.";
        };
        noindex = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Site helemaal niet indexeerbaar: Disallow: / voor iedereen + X-Robots-Tag.";
        };
        extraLocations = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Andere content-locations (naast \"/\") die ook de 403 moeten krijgen.";
        };
        allowAgents = lib.mkOption {
          type = lib.types.listOf (lib.types.strMatching "[A-Za-z0-9._-]+");
          default = [ ];
          example = [ "facebookexternalhit" ];
          description = "Botnamen uit de lijst die op deze site géén 403 en geen Disallow krijgen.";
        };
      };
    });
  };

  config = lib.mkIf (cfg.sites != { }) {
    services.nginx.commonHttpConfig = ''
      include ${stateDir}/ai-bots-map.conf;
    '' + lib.concatStrings (lib.mapAttrsToList allowMap
      (lib.filterAttrs (_: site: site.allowAgents != [ ]) cfg.sites));

    services.nginx.virtualHosts = lib.mapAttrs
      (vhost: site: {
        locations = {
          "= /robots.txt" = {
            alias = "${stateDir}/robots/${vhost}.txt";
            # try_files werkt niet samen met alias (grainwork zet die op zijn publieke paden)
            tryFiles = lib.mkForce null;
            extraConfig = ''
              default_type text/plain;
            '';
          };
        } // lib.genAttrs ([ "/" ] ++ site.extraLocations) (_: { extraConfig = blockIf vhost site; });
        extraConfig = lib.optionalString site.noindex ''
          add_header X-Robots-Tag "noindex, nofollow" always;
        '';
      })
      cfg.sites;

    systemd.tmpfiles.rules = [
      "d ${stateDir} 0755 root root -"
      "d ${stateDir}/robots 0755 root root -"
      "C ${stateDir}/ai-bots-map.conf 0644 root root - ${seedMap}"
    ];

    systemd.services.ai-blocklist = {
      description = "AI-crawler-blocklist voor nginx bijwerken";
      after = [ "network-online.target" "nginx.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [ config.systemd.package ];
      environment = {
        STATE_DIR = stateDir;
        SITES_JSON = sitesJson;
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = updater;
        # root: nginx -t (certs lezen) en systemctl reload nginx
        ProtectSystem = "full";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    };

    systemd.timers.ai-blocklist = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
    };

    systemd.paths.ai-blocklist = {
      wantedBy = [ "paths.target" ];
      pathConfig.PathChanged = lib.mapAttrsToList (vhost: _: "${toString vhosts.${vhost}.root}/robots.txt") cfg.sites;
    };
  };
}
