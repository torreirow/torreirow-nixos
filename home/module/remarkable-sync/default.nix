# home-manager module: reMarkable -> Nextcloud, via USB
#
# Haalt periodiek de documenten van een via USB aangesloten reMarkable op en zet
# ze in een map onder ~/Nextcloud, waar de bestaande `services.nextcloud-sync`
# ze vanzelf meeneemt. Twee onafhankelijke stappen, elk los uitschakelbaar:
#
#   backup  ruwe spiegel van de xochitl-map over SSH  -> <targetDir>/backup/
#   export  PDF per document via de USB-webinterface  -> <targetDir>/documenten/
#
# De export leunt op de renderer van het apparaat zelf: die tekent de inkt in de
# PDF (74 KB origineel -> 337 KB export, gemeten). Er is dus geen eigen
# .rm-renderer nodig.
#
# Voorwaarden die NIET door deze module geregeld worden (zie README.md):
#   - een SSH-sleutel in ~/.ssh-priv/ + authorized_keys op het apparaat;
#   - een NetworkManager-profiel op MAC-adres, declaratief in hosts/lobos/.
{ lib, pkgs, config, ... }:

with lib;

let
  cfg = config.services.remarkable-sync;

  # Expandeer een leidende ~ naar de absolute home-dir (systemd expandeert ~
  # niet in ExecStart-argumenten).
  normalizePath = p:
    if p == "~" then config.home.homeDirectory
    else if hasPrefix "~/" p then "${config.home.homeDirectory}/${removePrefix "~/" p}"
    else p;

  targetDir = normalizePath cfg.targetDir;
  stateDir = "${config.home.homeDirectory}/.local/state/remarkable-sync";

  exportScript = ./export.py;

  syncScript = pkgs.writeShellScript "remarkable-sync" ''
    set -uo pipefail

    # Een systemd user-service erft een kale PATH. Alles wat dit script en
    # export.py aanroepen (curl, bash voor /dev/tcp, timeout/mktemp/find) moet
    # er dus expliciet in.
    export PATH=${makeBinPath [ pkgs.curl pkgs.bash pkgs.coreutils pkgs.findutils ]}

    HOST=${escapeShellArg cfg.host}
    TARGET=${escapeShellArg targetDir}
    STATE_DIR=${escapeShellArg stateDir}

    mkdir -p "$TARGET" "$STATE_DIR"

    # --- Bereikbaarheidsprobe -------------------------------------------------
    # Het apparaat is er meestal NIET: hij slaapt (dan verdwijnt de complete
    # USB-gadget van de host) of de kabel ligt eruit. Dat is normaal gedrag en
    # geen fout -- een service die elke twee minuten faalt, traint je om
    # meldingen te negeren.
    probe() {
      timeout 3 bash -c "echo > /dev/tcp/$HOST/$1" 2>/dev/null
    }

    if ! probe 80 && ! probe 22; then
      echo "remarkable-sync: 10.11.99.1 antwoordt niet -- apparaat slaapt of is losgekoppeld."
      exit 0
    fi

    rc=0

    ${optionalString cfg.backup.enable ''
      # --- Ruwe backup over SSH ----------------------------------------------
      # tar over de lijn, daarna lokaal rsync'en. Direct uitpakken zou elk
      # bestand herschrijven; rsync laat ongewijzigde bestanden met rust, zodat
      # nextcloudcmd ze niet opnieuw upload.
      if probe 22; then
        tmp=$(mktemp -d "$STATE_DIR/backup.XXXXXX")
        trap 'rm -rf "$tmp"' EXIT
        if ${pkgs.openssh}/bin/ssh \
              -i ${escapeShellArg (normalizePath cfg.sshIdentityFile)} \
              -o BatchMode=yes \
              -o StrictHostKeyChecking=accept-new \
              -o UserKnownHostsFile="$STATE_DIR/known_hosts" \
              -o ConnectTimeout=10 \
              ${escapeShellArg cfg.sshUser}@"$HOST" \
              'tar -cf - -C /home/root/.local/share/remarkable xochitl' \
           | ${pkgs.gnutar}/bin/tar -xf - -C "$tmp"; then
          mkdir -p "$TARGET/backup"
          ${pkgs.rsync}/bin/rsync -a --delete "$tmp/xochitl/" "$TARGET/backup/xochitl/"
          echo "remarkable-sync: backup bijgewerkt ($(find "$TARGET/backup/xochitl" -type f | wc -l) bestanden)"
        else
          echo "remarkable-sync: backup overgeslagen (SSH niet gelukt)" >&2
          rc=1
        fi
        rm -rf "$tmp"
        trap - EXIT
      fi
    ''}

    ${optionalString cfg.export.enable ''
      # --- PDF-export via de webinterface ------------------------------------
      if probe 80; then
        ${pkgs.python3}/bin/python3 ${exportScript} \
          --host "$HOST" \
          --target "$TARGET/documenten" \
          --state "$STATE_DIR/exported.json" || rc=1
      fi
    ''}

    exit $rc
  '';

in
{
  options.services.remarkable-sync = {
    enable = mkEnableOption "periodieke sync van een via USB aangesloten reMarkable naar een Nextcloud-map";

    host = mkOption {
      type = types.str;
      default = "10.11.99.1";
      description = ''
        Adres van het apparaat. Over USB draait de reMarkable een CDC-ethernet
        gadget op 10.11.99.1 en deelt hij via DHCP een adres in 10.11.99.0/27 uit.
      '';
    };

    targetDir = mkOption {
      type = types.str;
      default = "~/Nextcloud/reMarkable";
      description = ''
        Map waarin `backup/` en `documenten/` landen. Een leidende `~/` wordt
        geëxpandeerd. Zet dit onder de map die `services.nextcloud-sync` synct,
        dan gaat de rest vanzelf.

        Let op: die map synct twee kanten op. Verwijder je elders een
        geëxporteerde PDF, dan zet de volgende run hem terug -- de map is een
        spiegel van het apparaat, geen prullenbak.
      '';
    };

    interval = mkOption {
      type = types.str;
      default = "2min";
      description = ''
        Sync-interval als systemd-tijdspanne (`OnUnitActiveSec`). Kort mag: is
        het apparaat er niet, dan kost een run alleen een TCP-probe.
      '';
    };

    sshUser = mkOption {
      type = types.str;
      default = "root";
      description = "Gebruiker op het apparaat. De reMarkable kent alleen `root`.";
    };

    sshIdentityFile = mkOption {
      type = types.str;
      default = "~/.ssh-priv/remarkable";
      description = ''
        Private sleutel voor de backup-stap. Bewust een los bestand met een
        expliciet pad: op lobos is `rbw` de ssh-agent en die serveert uitsluitend
        sleutels uit de Bitwarden-kluis, dus `ssh-add` is geen optie. Zie README.md.
      '';
    };

    backup.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Ruwe spiegel van de xochitl-map over SSH (de verzekering: exact herstelbaar).";
    };

    export.enable = mkOption {
      type = types.bool;
      default = true;
      description = "PDF per document via de USB-webinterface (het gemak: leesbaar op elk apparaat).";
    };

    onFailure = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = literalExpression ''[ "notify-signal@%N.service" ]'';
      description = ''
        Units die systemd start zodra de sync faalt (`Unit.OnFailure`). Let op:
        een afwezig apparaat is géén fout -- de sync eindigt dan met exit 0 -- dus
        dit vuurt alleen bij een echt probleem, niet elke keer dat de tablet slaapt.
      '';
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.rsync ];

    systemd.user.services.remarkable-sync = {
      Unit = {
        Description = "reMarkable sync naar ${cfg.targetDir}";
      } // optionalAttrs (cfg.onFailure != [ ]) {
        OnFailure = cfg.onFailure;
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${syncScript}";
      };
    };

    systemd.user.timers.remarkable-sync = {
      Unit.Description = "Timer voor de reMarkable-sync";
      Timer = {
        OnActiveSec = "1min";
        OnUnitActiveSec = cfg.interval;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
