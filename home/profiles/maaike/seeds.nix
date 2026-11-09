# App-standaarden van maaike: per app de bestanden in $HOME en hun bron. Eén lijst en één script
# voor twee routes: de HM-activatie seedt (alleen ontbrekende bestanden), herstel-app draait het
# met --force (eerst *.bak-<datum>). Zie docs/maaike-app-defaults.md.
{ pkgs, lib }:

let
  # Minimale state voor bitwarden-desktop: alleen de server. Formaat uit de app.asar van
  # 2026.8.0 (StateDefinition "environment", key "environment"; CURRENT_VERSION 83). Met
  # stateVersion migreert de app vanaf daar in plaats van het bestand als leeg te behandelen.
  bitwardenData = pkgs.writeText "bitwarden-data.json" (builtins.toJSON {
    stateVersion = 83;
    global_environment_environment = {
      region = "Self-hosted";
      urls.base = "https://vw.toorren.net";
    };
  });

  smplayerIni = pkgs.writeText "smplayer.ini" ''
    [performance]
    hwdec=auto
  '';

  # Audacity neemt op van de podcastbron (ALSA-apparaat `podcast` = "Podcast (2 mics)", links mic 1,
  # rechts mic 2; modules/podcast-opname). Alleen [AudioIO]; de rest vult Audacity zelf aan.
  audacityCfg = pkgs.writeText "audacity.cfg" ''
    [AudioIO]
    Host=ALSA
    RecordingDevice=podcast
    RecordChannels=2
  '';

  # files: pad onder $HOME -> bron. process: pkill -f-patroon (hoofdletterongevoelig).
  apps = {
    nextcloud = {
      files.".config/Nextcloud/nextcloud.cfg" = ./defaults/nextcloud.cfg;
      process = "nextcloud";
    };
    bitwarden = {
      files.".config/Bitwarden/data.json" = bitwardenData;
      process = "bitwarden";
    };
    zapzap = {
      files.".config/ZapZap/ZapZap.conf" = ./defaults/ZapZap.conf;
      process = "zapzap";
    };
    smplayer = {
      files.".config/smplayer/smplayer.ini" = smplayerIni;
      process = "smplayer";
    };
    audacity = {
      files.".config/audacity/audacity.cfg" = audacityCfg;
      process = "audacity";
    };
  };

  seedApp = name: app: ''
    ${name})
    ${lib.concatStrings (lib.mapAttrsToList (rel: src: ''
      seed ${name} ${src} ${lib.escapeShellArg rel}
    '') app.files)}  ;;
  '';
in
{
  inherit apps;

  # seed-apps [--force] <app>...: draait als de gebruiker zelf, met $HOME gezet.
  script = pkgs.writeShellScript "seed-apps" ''
    set -euo pipefail
    force=0
    if [[ "''${1:-}" == --force ]]; then force=1; shift; fi
    stamp=$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)

    seed() {
      local app=$1 src=$2 dst="$HOME/$3"
      if [[ -e "$dst" || -L "$dst" ]]; then
        (( force )) || return 0
        ${pkgs.coreutils}/bin/mv "$dst" "$dst.bak-$stamp"
        echo "$app: oude versie bewaard als $dst.bak-$stamp"
      fi
      ${pkgs.coreutils}/bin/install -D -m 0600 "$src" "$dst"
      echo "$app: standaard neergezet in $dst"
    }

    for app in "$@"; do
      case "$app" in
      ${lib.concatStrings (lib.mapAttrsToList seedApp apps)}
      *) echo "seed-apps: onbekende app '$app'" >&2; exit 1 ;;
      esac
    done
  '';
}
