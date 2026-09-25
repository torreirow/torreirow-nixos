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
        Hostnaam waarop de MCP-server bereikbaar is.

        Een custom connector op claude.ai wordt server-side door Anthropic
        opgehaald, niet door de browser of de telefoon; die route vereist dus een
        publiek bereikbaar endpoint. Zolang de organisatie geen custom connectors
        toestaat is die route dicht en zijn de clients lokaal (Claude Code,
        Claude Desktop) -- vandaar `allowedNetworks`, dat het bereik terugbrengt
        tot LAN en wireguard. Zet dat op `[ ]` om weer publiek te gaan.
      '';
    };

    acmeHost = mkOption {
      type = types.str;
      default = "toorren.net";
      description = "ACME-host voor het (wildcard) TLS-certificaat.";
    };

    publicEndpoint = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Of er een publieke nginx-vhost op `domain` komt.

        Alleen zinvol zodra claude.ai custom connectors toestaat: die worden
        server-side door Anthropic opgehaald en vereisen dus een publiek
        endpoint. Lokale clients (Claude Code, Claude Desktop) bereiken de
        server via een SSH-tunnel naar 127.0.0.1:<port> en hebben deze vhost
        niet nodig.

        Een IP-filter op de vhost is géén alternatief voor "alleen LAN". De naam
        wijst naar het publieke adres, dus ook verkeer van het eigen netwerk gaat
        naar buiten en komt via de router terug; nginx ziet dan het WAN-adres.
        Er bestaat in deze opstelling simpelweg geen bronadres dat "LAN" betekent.
      '';
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
    systemd.services.linny-mcp = {
      restartTriggers = [ config.age.secrets.linny-mcp-tokens.file ];
      # Zelfde reden als bij clone/git-sync: het tokenbestand ligt onder /run/keys.
      serviceConfig.SupplementaryGroups = [ "keys" ];
    };

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
        # /run/keys is root:keys 0750 -- zonder deze groep is de agenix-secret
        # onbereikbaar, ook al is het bestand zelf eigendom van deze user.
        SupplementaryGroups = [ "keys" ];
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
        # /run/keys is root:keys 0750 -- zonder deze groep is de agenix-secret
        # onbereikbaar, ook al is het bestand zelf eigendom van deze user.
        SupplementaryGroups = [ "keys" ];
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
        # /run/keys is root:keys 0750 -- zonder deze groep is de agenix-secret
        # onbereikbaar, ook al is het bestand zelf eigendom van deze user.
        SupplementaryGroups = [ "keys" ];
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
    services.nginx.virtualHosts = mkIf cfg.publicEndpoint {
      ${cfg.domain} = {
      forceSSL = true;
      useACMEHost = cfg.acmeHost;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.port}";
        # forceert HTTP/1.1 + Upgrade/Connection
        proxyWebsockets = true;
        # De aanbevolen headers zetten `Host $host`, en dat botst met de
        # DNS-rebinding-bescherming van de MCP-SDK: die springt automatisch aan
        # zodra de server op loopback luistert en weigert dan elke Host die geen
        # loopback-naam is (streamable.go: "Forbidden: invalid Host header").
        # Daarom zelf de headers zetten -- twee keer proxy_set_header Host zou
        # nginx allebei meesturen en Go antwoordt dan met 400.
        # `req.Host` wordt in de SDK nergens anders gebruikt dan in die check,
        # dus overschrijven kost geen functionaliteit.
        recommendedProxySettings = false;
        # MCP's streamable-HTTP (SSE) mag niet gebufferd worden en heeft een lange
        # upstream-read nodig, anders stallen of breken langlopende /mcp-streams.
        extraConfig = ''
          proxy_set_header Host localhost;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Host $host;

          proxy_buffering off;
          proxy_request_buffering off;
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
          chunked_transfer_encoding off;
        '';
      };
      };
    };
  };
}
