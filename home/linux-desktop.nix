{config,pkgs,...}: {
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

# Headless Nextcloud-sync (module: home/module/nextcloud-sync).
# Credentials (NC_USER/NC_PASSWORD, app-password) staan handmatig in
# ~/.config/nextcloud-sync/credentials (0600), bewust niet in de nix-store.
# Faalmeldingen naar Signal via Home Assistant (notify.signal_maria).
# Token komt uit agenix: age.secrets.ha-token in hosts/lobos/lobos-secrets.nix.
# Waarom via HA en niet rechtstreeks: de signal-cli REST API op malandro
# luistert alleen op 127.0.0.1 en is vanaf lobos onbereikbaar.
services.notify-signal.enable = true;

services.nextcloud-sync = {
  enable = true;
  # BEWUST GEEN onFailure hier. De Nextcloud-server (bobadela1) gaat 's nachts uit
  # en wordt 's ochtends handmatig gewekt; een melding per mislukking gaf daardoor
  # elke ochtend loos alarm. De staleness-monitor hieronder neemt die rol over en
  # meet het resultaat ("is er nog gesynct?") in plaats van de storing.
  syncs.docs = {
    serverUrl = "https://nxc.toorren.net";
    localPath = "~/Nextcloud";
    # remotePath = "/";     # optioneel: alleen een submap syncen
    # interval   = "10min"; # default (OnUnitActiveSec)
    # trust      = false;   # true bij self-signed certificaat
  };
};

# reMarkable via USB -> ~/Nextcloud/reMarkable (module: home/module/remarkable-sync).
# Landt onder ~/Nextcloud, dus de sync hierboven neemt het vanzelf mee.
# Handmatig vooraf: USB-webinterface aanzetten op het apparaat en een SSH-sleutel
# in ~/.ssh-priv/remarkable neerleggen -- zie de README van de module.
# Dagelijkse controle of er nog gesynct is (module: home/module/staleness-monitor).
# Twee drempels: binnen 24-48u alleen melden als de server ook echt antwoordt,
# zodat het ochtendgat waarin bobadela1 nog uit staat stil blijft. Na 48u altijd,
# zodat een server die dagen uit blijft alsnog een herinnering oplevert.
services.staleness-monitor = {
  enable = true;
  # 20:00: tegen die tijd heeft de server de hele dag aan gestaan. Sliep lobos op
  # dat moment, dan haalt Persistent=true het in zodra hij wakker is.
  checkTime = "20:00";
  watch.nextcloud = {
    stampFile = config.services.nextcloud-sync.stampFiles.docs;
    message = "Nextcloud-sync op lobos is te lang niet gelukt";
    # Toetst op INHOUD, niet op de statuscode: er staat een nginx vóór Nextcloud
    # die ook antwoordt als de backend plat ligt (dan met 502), en een captive
    # portal geeft vrolijk 200 met HTML terug. --fail vangt de 502, jq -e eist dat
    # het echt een draaiende, niet-onderhoudende Nextcloud is.
    readinessCommand = ''
      ${pkgs.curl}/bin/curl -sS --fail --max-time 10 https://nxc.toorren.net/status.php \
        | ${pkgs.jq}/bin/jq -e '.installed == true and .maintenance == false' >/dev/null
    '';
  };
};

# Meeting-opname: beide kanten van een gesprek als twee sporen
# (module: home/module/meeting-record). Neemt nooit uit zichzelf op --
# `meetrec start` is altijd een expliciete handeling.
services.meeting-record = {
  enable = true;
  # targetDir       = "~/Meetings";  # default
  # opusBitrate     = "32k";         # spraak; ~15 MB/uur per spoor
  # mixWeights      = "1 1";         # volgorde: anderen ik
  # whisperModel    = "turbo";
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

services.remarkable-sync = {
  enable = true;
  # Een slapend/losgekoppeld apparaat is exit 0, dus dit vuurt alleen bij een
  # echt probleem (SSH stuk, webinterface uit, download mislukt).
  onFailure = [ "notify-signal@%N.service" ];
  # targetDir     = "~/Nextcloud/reMarkable";  # default
  # interval      = "2min";                    # default
  # backup.enable = true;                      # ruwe xochitl-spiegel over SSH
  # export.enable = true;                      # PDF's via de USB-webinterface
};

}
