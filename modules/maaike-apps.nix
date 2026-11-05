# App-standaarden voor maaike: home-manager (alleen seeds, geen Plasma), herstel-app en de
# Spotify-login via agenix. Eén regel op de host:
#
#   toorren.maaike.enable = true;
#
# Verwacht dat home-manager.nixosModules.home-manager al geïmporteerd is (op mpenzi doet
# modules/wtoorren-admin.nix dat) en agenix voor spotifyPrefs. Zie docs/maaike-app-defaults.md.
{ config, lib, pkgs, ... }:

let
  cfg = config.toorren.maaike;
  user = "maaike";
  home = config.users.users.${user}.home;
  seeds = import ../home/profiles/maaike/seeds.nix { inherit pkgs lib; };
  spotifyPrefs = "${home}/.config/spotify/prefs";

  appNames = lib.attrNames seeds.apps ++ [ "spotify" "signal" ];

  # herstel-app <gebruiker> <app|all>: app stoppen, oude config naar *.bak-<datum>, standaard
  # terug. Draait als root; het kopiëren gebeurt als de gebruiker zelf.
  herstelApp = pkgs.writeShellApplication {
    name = "herstel-app";
    runtimeInputs = with pkgs; [ coreutils procps util-linux getent ];
    text = ''
      usage() {
        echo "gebruik: herstel-app <gebruiker> <app|all>" >&2
        echo "  gebruikers: ${user}" >&2
        echo "  apps: ${lib.concatStringsSep " " appNames} all" >&2
        exit 2
      }
      [[ $# -eq 2 ]] || usage
      user=$1 app=$2
      [[ "$user" == ${user} ]] || { echo "herstel-app: onbekende gebruiker '$user'" >&2; usage; }
      [[ $EUID -eq 0 ]] || { echo "herstel-app: draai met sudo" >&2; exit 1; }
      home=$(getent passwd "$user" | cut -d: -f6)

      stop() {
        if pkill -i -u "$user" -f "$1"; then
          echo "$2: gestopt"
          sleep 2
        fi
      }

      seed() {
        runuser -u "$user" -- env HOME="$home" ${seeds.script} --force "$1"
      }

      spotify() {
        ${if cfg.spotifyPrefs == null then ''
          echo "spotify: geen secrets/spotify-maaike.age op deze host; $user logt zelf in." >&2
        '' else ''
          stop spotify spotify
          local prefs=${lib.escapeShellArg spotifyPrefs}
          local target="${config.age.secretsDir}/spotify-maaike"
          if [[ -e "$prefs" || -L "$prefs" ]] && [[ "$(readlink "$prefs")" != "$target" ]]; then
            mv "$prefs" "$prefs.bak-$(date +%Y%m%d-%H%M%S)"
            echo "spotify: oude prefs bewaard als .bak"
          fi
          ln -sfn "$target" "$prefs"
          echo "spotify: login-prefs teruggezet"
        ''}
      }

      signal() {
        echo "signal: geen standaard (config.json bevat een sleutel). Herstel = opnieuw koppelen:"
        echo "  Signal openen, QR-code scannen met de telefoon (Instellingen > Gekoppelde apparaten)."
      }

      herstel() {
        case "$1" in
          ${lib.concatStrings (lib.mapAttrsToList (name: app: ''
            ${name}) stop ${lib.escapeShellArg app.process} ${name}; seed ${name} ;;
          '') seeds.apps)}
          spotify) spotify ;;
          signal) signal ;;
          *) echo "herstel-app: onbekende app '$1'" >&2; usage ;;
        esac
      }

      if [[ "$app" == all ]]; then
        for a in ${lib.concatStringsSep " " (lib.attrNames seeds.apps)} spotify; do herstel "$a"; done
      else
        herstel "$app"
      fi
      echo "Klaar. $user start de app opnieuw; hooguit wachtwoord of QR-code invoeren."
    '';
  };
in
{
  options.toorren.maaike = {
    enable = lib.mkEnableOption "app-standaarden en herstel-app voor maaike";

    spotifyPrefs = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        agenix-bestand met de Spotify-prefs (autologin) van maaike, of null. Wordt ontsleuteld
        naar ~/.config/spotify/prefs.
      '';
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      home-manager.useGlobalPkgs = true;
      home-manager.users.${user} = {
        imports = [ ../home/profiles/maaike ];
        home.stateVersion = config.system.stateVersion;
      };

      environment.systemPackages = [ herstelApp ];

      # agenix maakt ontbrekende mappen als root aan; `d` zet ze (terug) op naam van maaike.
      systemd.tmpfiles.rules = [
        "d ${home}/.config 0700 ${user} users -"
        "d ${home}/.config/spotify 0700 ${user} users -"
      ];

      warnings = lib.optional (cfg.spotifyPrefs == null)
        "toorren.maaike: geen spotify-maaike.age; Spotify vraagt maaike zelf om in te loggen.";
    }

    (lib.mkIf (cfg.spotifyPrefs != null) {
      age.secrets.spotify-maaike = {
        file = cfg.spotifyPrefs;
        path = spotifyPrefs;
        owner = user;
        group = "users";
        mode = "0600";
      };
    })
  ]);
}
