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
services.nextcloud-sync = {
  enable = true;
  syncs.docs = {
    serverUrl = "https://nxc.toorren.net";
    localPath = "~/Nextcloud";
    # remotePath = "/";     # optioneel: alleen een submap syncen
    # interval   = "10min"; # default (OnUnitActiveSec)
    # trust      = false;   # true bij self-signed certificaat
  };
};

}
