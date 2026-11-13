{config,pkgs,lib,...}: {
 imports = [
  ./overlays.nix
  ./zsh.nix
  ./awsconf.nix
  ./tmux.nix
  ./common.nix
  ./vim.nix
  ./jj.nix
  ./dotfiles
  ./gnome-desktop
#  ./librewolf.nix
#  ./sshkeys.nix
#  ./dotfiles/toggl-secret.nix
];

#services.flameshot= {
#  enable = true;
#  settings = {
#    General = {
#      disabledTrayIcon = false;
#      showStartupLaunchMessage = true;
#    };
#  };
#
#};

systemd.user.services.evolution-alarm-notify = {
  Unit = {
    Description = "Event and Task Reminders";
    PartOf = [ "graphical-session.target" ];
    After = [ "graphical-session.target" ];
    ConditionEnvironment = "WAYLAND_DISPLAY";
  };
  Service = {
    Type = "dbus";
    BusName = "org.gnome.Evolution-alarm-notify";
    ExecStart = "${pkgs.evolution-data-server}/libexec/evolution-data-server/evolution-alarm-notify";
    Restart = "on-failure";
  };
  Install.WantedBy = [ "graphical-session.target" ];
};

# Faalmeldingen naar Signal via Home Assistant (notify.signal_maria); o.a. remarkable-sync.
# Token komt uit agenix: age.secrets.ha-token in hosts/lobos/lobos-secrets.nix.
# Waarom via HA en niet rechtstreeks: de signal-cli REST API op malandro
# luistert alleen op 127.0.0.1 en is vanaf lobos onbereikbaar.
services.notify-signal.enable = true;

# Nextcloud: alleen de GUI-client, die ~/Documents <-> /Documents live synct (tray-icoon).
# De headless nextcloud-sync (~/Nextcloud, timer) is op 2026-11-05 weggehaald: /Documents stond
# daardoor dubbel lokaal (6,9 GB) en de rest van de server hoeft niet naar lobos.
# De wrapper laat maar één GUI-instantie toe (zie module/nextcloud-gui/single-instance.nix).
home.packages = [ (pkgs.callPackage ./module/nextcloud-gui/single-instance.nix { }) ];

xdg.configFile."autostart/Nextcloud.desktop".text = ''
  [Desktop Entry]
  Name=Nextcloud
  GenericName=File Synchronizer
  Exec=nextcloud --background
  Terminal=false
  Icon=Nextcloud
  Categories=Network
  Type=Application
  StartupNotify=false
  X-GNOME-Autostart-enabled=true
  X-GNOME-Autostart-Delay=10
'';

# Startconfig van de GUI-client (account nxc.toorren.net, map ~/Documents). Alleen neerzetten
# als hij ontbreekt: de client schrijft zelf in nextcloud.cfg, dus geen read-only symlink.
# Het app-wachtwoord staat in de keyring, niet in dit bestand. Selectieve sync (o.a.
# Onedrive-ECMI-backup uit) staat in de sync-journal, niet hier.
home.activation.nextcloudConfigSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  if [ ! -e "$HOME/.config/Nextcloud/nextcloud.cfg" ]; then
    run mkdir -p "$HOME/.config/Nextcloud"
    run install -m 644 ${./dotfiles/nextcloud/nextcloud-lobos.cfg} "$HOME/.config/Nextcloud/nextcloud.cfg"
  fi
'';

# reMarkable via USB -> ~/Documents/reMarkable (module: home/module/remarkable-sync).
# Landt in ~/Documents, dat de Nextcloud GUI-client live synct.
# Handmatig vooraf: USB-webinterface aanzetten op het apparaat en een SSH-sleutel
# in ~/.ssh-priv/remarkable neerleggen -- zie de README van de module.
# staleness-monitor uit: hij bewaakte alleen de headless Nextcloud-sync, die weg is. De GUI-client
# laat zelf in het tray-icoon zien of hij synct.

# Meeting-opname: beide kanten van een gesprek als twee sporen
# (module: home/module/meeting-record). Neemt nooit uit zichzelf op --
# `meetrec start` is altijd een expliciete handeling.
services.meeting-record = {
  enable = true;
  # targetDir       = "~/Meetings";  # default
  # opusBitrate     = "32k";         # spraak; ~15 MB/uur per spoor
  # mixWeights      = "1 1";         # volgorde: anderen ik
  # whisperModel    = "/nix/store/...-ggml-large-v3-turbo.bin";  # default: large-v3-turbo
  # whisperGpu      = true;         # false = CPU (-ng)
  # whisperLanguage = "nl";
};

# Notitieboek als MCP-server, bereikbaar op 127.0.0.1:8096
# (module: home/module/linny-mcp-tunnel). De server zelf draait op malandro en
# staat niet publiek; ssh-toegang tot malandro is het toegangsbewijs.
services.linny-mcp-tunnel = {
  enable = true;
  # host       = "malandro";  # default
  # localPort  = 8096;        # default
  # remotePort = 8096;        # default
};

# Clipboard-afbeeldingen naar Claude Code op malandro (module: home/module/clipbridge).
# Alleen image/*; malandro heeft services.clipbridge.shim via linux-server.nix.
services.clipbridge.serve = {
  enable = true;
  # host         = "malandro";                              # default
  # remoteSocket = "/home/wtoorren/.cache/clipbridge.sock"; # default
};

services.remarkable-sync = {
  enable = true;
  # Een slapend/losgekoppeld apparaat is exit 0, dus dit vuurt alleen bij een
  # echt probleem (SSH stuk, webinterface uit, download mislukt).
  onFailure = [ "notify-signal@%N.service" ];
  # In ~/Documents, zodat de Nextcloud GUI-client het live synct (naar /Documents/reMarkable).
  targetDir = "~/Documents/reMarkable";
  # interval      = "2min";                    # default
  # backup.enable = true;                      # ruwe xochitl-spiegel over SSH
  # export.enable = true;                      # PDF's via de USB-webinterface
};

}
