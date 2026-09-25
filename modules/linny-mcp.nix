{ config, lib, pkgs, ... }:

# linny-mcp — het torrlinny-notitieboek als SCHRIJFBAAR tweede brein voor Claude.
#
# Dunne wrapper rond de upstream `services.linny-mcp` (flake-input linny-mcp,
# github:linden-project/linny-mcp-server), naar het model van modules/torrlinny.nix.
# De wrapper voegt het malandro-specifieke toe: een eigen corpus-clone, de
# bidirectionele git-sync, de indexer, de agenix-secrets en de publieke vhost.
#
# ── WAAROM EEN EIGEN CORPUS-CLONE ────────────────────────────────────────────
# De notities staan al op malandro in /var/lib/torrlinny/checkout, maar die map is
# van linny-web-build en wordt elke ~3 minuten zo behandeld:
#
#     git -C "$CHECKOUT" reset --hard "origin/main"
#     git -C "$CHECKOUT" clean -fdx
#
# Een notitie die de agent net heeft geschreven is een UNTRACKED bestand; `clean
# -fdx` wist die. Is hij lokaal gecommit maar nog niet gepusht, dan gooit `reset
# --hard` hem alsnog weg. Landt de Hugo-build in dat venster, dan is de notitie
# stil verdwenen -- zonder foutmelding, want vanuit de build klopt alles.
# Daarom een eigen werkmap. GitHub is het knooppunt voor alle drie de deelnemers
# (lobos/NeoVim, de agent hier, en de Hugo-build). Prijs: een agent-notitie staat
# pas na ~4 min op linny.toorren.net. Zie openspec/changes/add-linny-mcp-hosting.
#
# ── SCHRIJFGRENS ─────────────────────────────────────────────────────────────
# quarantine = true zet agent-documenten in de frontmatter-term `status: agent-draft`.
# Dat doet pas iets samen met de tokenscope `write:inbox`: daarmee maakt de agent
# nieuwe documenten en werkt hij alleen zijn eigen nog-niet-gepromoveerde drafts
# bij. Bestaande, met de hand geschreven notities zijn onaanraakbaar. Met `write:*`
# was de term slechts een sticker die de agent zelf kan weghalen. De scopes staan
# in het tokens-secret, niet hier.

with lib;

let
  cfg = config.services.linny-mcp-host;

  user = "linny-mcp";
  corpusDir = "${cfg.stateRoot}/corpus";
  indexStateDir = "${cfg.stateRoot}/state";
  knownHosts = "${cfg.stateRoot}/known_hosts";

  deployKey = config.age.secrets.linny-mcp-deploy-key.path;

  # known_hosts staat BUITEN de working tree, anders probeert git-sync dat bestand
  # mee te synchroniseren naar de notitie-repo.
  sshCmd = concatStringsSep " " [
    "${pkgs.openssh}/bin/ssh"
    "-i ${deployKey}"
    "-o IdentitiesOnly=yes"
    "-o StrictHostKeyChecking=accept-new"
    "-o UserKnownHostsFile=${knownHosts}"
  ];

  lindexer = "${config.services.linny-mcp.package}/bin/lindexer";
  jsonIndex = "${indexStateDir}/lindenIndex";
in
{
  options.services.linny-mcp-host = {
    enable = mkEnableOption "linny-mcp: torrlinny als schrijfbaar tweede brein voor MCP-clients";

    domain = mkOption {
      type = types.str;
      default = "linny-mcp.toorren.net";
      description = ''
        Publieke hostnaam waarop de MCP-server bereikbaar is. Moet publiek zijn:
        een custom connector op claude.ai wordt server-side door Anthropic
        opgehaald, niet door de browser of de telefoon, dus een endpoint binnen
        wireguard is voor Claude Online en Mobile onbereikbaar.
      '';
    };

    acmeHost = mkOption {
      type = types.str;
      default = "toorren.net";
      description = "ACME-host voor het (wildcard) TLS-certificaat.";
    };

    port = mkOption {
      type = types.port;
      default = 8096;
      description = "Lokale poort waarop linny-mcp luistert. Zie PORTS.md.";
    };

    stateRoot = mkOption {
      type = types.str;
      default = "/var/lib/linny-mcp";
      description = ''
        Basismap voor het corpus en de wegwerp-index. Moet buiten /home liggen:
        de upstream-unit zet `ProtectHome = true`, waardoor /home leeg is in de
        sandbox en `ReadWritePaths` daar niet doorheen prikt.
      '';
    };

    gitRepo = mkOption {
      type = types.str;
      default = "git@github.com:torreirow/torrlinny.git";
      description = "De notitie-repo die als corpus dient.";
    };

    branch = mkOption {
      type = types.str;
      default = "main";
      description = "Branch die gesynchroniseerd wordt.";
    };

    syncInterval = mkOption {
      type = types.str;
      default = "30s";
      description = "Hoe vaak git-sync draait.";
    };
  };

  config = mkIf cfg.enable {

    ###### Secrets ###########################################################
    # Alleen PADEN belanden in Nix-opties; opties staan wereldleesbaar in de
    # nix-store, dus nooit een tokenwaarde of sleutel hier.
    age.secrets.linny-mcp-deploy-key = {
      file = ../secrets/linny-mcp-deploy-key.age;
      path = "/run/agenix/linny-mcp-deploy-key";
      owner = user;
      mode = "0400";
    };

    age.secrets.linny-mcp-tokens = {
      file = ../secrets/linny-mcp-tokens.age;
      path = "/run/agenix/linny-mcp-tokens";
      owner = user;
      mode = "0400";
    };

    ###### De upstream-service ###############################################
    services.linny-mcp = {
      enable = true;
      # Loopback volstaat: nginx draait op dezelfde host. De bind-safety van de
      # server (internal/config/bind.go) accepteert loopback en RFC1918 en weigert
      # publieke adressen en 0.0.0.0 -- er is dus geen override nodig.
      listenAddress = "127.0.0.1";
      port = cfg.port;
      publicHostname = cfg.domain;
      corpusPath = corpusDir;
      stateDir = indexStateDir;
      tokensFile = config.age.secrets.linny-mcp-tokens.path;
      quarantine = true;   # hostile-corpus-defense; zie kop van dit bestand
      readOnly = false;    # schrijfbaar brein
    };

    # De server leest het tokenbestand EENMALIG bij start en herlaadt het nooit.
    # Hercoderen van het secret laat de unitdefinitie byte-identiek, dus zonder
    # deze trigger zou een `switch` de oude scopes in geheugen houden. Triggeren
    # op het ciphertext-pad: dat verandert bij elke hercodering.
    systemd.services.linny-mcp.restartTriggers = [
      config.age.secrets.linny-mcp-tokens.file
    ];

    # Corpus en state moeten BESTAAN voordat de unit start: ReadWritePaths
    # bind-mount ze, en een ontbrekend pad faalt met 226/NAMESPACE nog voor exec.
    systemd.tmpfiles.rules = [
      "d ${cfg.stateRoot} 0750 ${user} ${user} - -"
      "d ${corpusDir}     0750 ${user} ${user} - -"
      "d ${indexStateDir} 0750 ${user} ${user} - -"
    ];

    ###### Corpus: eenmalige clone ###########################################
    systemd.services.linny-mcp-clone = {
      description = "bootstrap-clone van het torrlinny-corpus voor linny-mcp";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      before = [ "linny-mcp.service" "linny-mcp-index.service" ];
      wantedBy = [ "multi-user.target" ];
      environment.GIT_SSH_COMMAND = sshCmd;
      path = [ pkgs.git pkgs.openssh ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = user;
        Group = user;
      };
      script = ''
        if [ ! -e ${corpusDir}/.git ]; then
          git clone --branch ${cfg.branch} ${cfg.gitRepo} ${corpusDir}
        fi
      '';
    };

    ###### Corpus: bidirectionele sync #######################################
    systemd.services.linny-mcp-git-sync = {
      description = "bidirectionele git-sync van het linny-mcp-corpus";
      after = [ "linny-mcp-clone.service" "network-online.target" ];
      wants = [ "network-online.target" ];
      requires = [ "linny-mcp-clone.service" ];
      environment.GIT_SSH_COMMAND = sshCmd;
      path = [ pkgs.git pkgs.git-sync pkgs.openssh ];
      serviceConfig = {
        Type = "oneshot";
        User = user;
        Group = user;
        WorkingDirectory = corpusDir;
      };
      script = ''
        git config user.name  "linny-mcp"
        git config user.email "linny-mcp@malandro"
        # git-sync weigert een branch die niet expliciet is opgegeven, en agent-
        # writes zijn untracked tot ze gecommit worden -- vandaar syncNewFiles.
        git config --bool branch.${cfg.branch}.sync true
        git config --bool branch.${cfg.branch}.syncNewFiles true
        exec git-sync -n
      '';
    };

    systemd.timers.linny-mcp-git-sync = {
      description = "draai de git-sync van het linny-mcp-corpus";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = cfg.syncInterval;
        Unit = "linny-mcp-git-sync.service";
      };
    };

    ###### Index #############################################################
    # `linny-mcp serve` LEEST alleen een index en bouwt er nooit een; bovendien
    # herindexeert het alleen zijn eigen writes. Zonder deze unit zien clients nul
    # documenten en worden notities die via git-sync binnenkomen nooit vindbaar.
    # De gegenereerde index gaat naar de wegwerp-state-dir, nooit in de
    # git-tracked corpus -- anders commit en pusht git-sync index-artefacten.
    systemd.services.linny-mcp-index = {
      description = "linny-mcp corpus-indexer (volledige build + fsnotify-watch)";
      after = [ "linny-mcp-clone.service" ];
      requires = [ "linny-mcp-clone.service" ];
      before = [ "linny-mcp.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = user;
        Group = user;
        Restart = "on-failure";
        RestartSec = 5;
        # ExecStartPre is klaar voordat de unit als gestart geldt, dus
        # linny-mcp.service (erna geordend) ziet een gevulde index.
        ExecStartPre = "${lindexer} build -corpus ${corpusDir} -index ${jsonIndex} -state-dir ${indexStateDir}";
        ExecStart = "${lindexer} watch -corpus ${corpusDir} -index ${jsonIndex} -state-dir ${indexStateDir}";
      };
    };

    ###### Publieke vhost ####################################################
    # BEWUST ZONDER AUTHELIA. Dat is een redirect-gebaseerde browserflow; een
    # MCP-client stuurt alleen `Authorization: Bearer` en volgt geen redirect.
    # De authenticatie zit in linny-mcp zelf (bearer-tokens uit agenix).
    services.nginx.virtualHosts.${cfg.domain} = {
      forceSSL = true;
      useACMEHost = cfg.acmeHost;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.port}";
        # forceert HTTP/1.1 + Upgrade/Connection
        proxyWebsockets = true;
        # MCP's streamable-HTTP (SSE) mag niet gebufferd worden en heeft een lange
        # upstream-read nodig, anders stallen of breken langlopende /mcp-streams.
        extraConfig = ''
          proxy_buffering off;
          proxy_request_buffering off;
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
          chunked_transfer_encoding off;
        '';
      };
    };
  };
}
