{ config, pkgs, lib, ... }:
{
  home.file = lib.mkIf (builtins.pathExists "/tmp/togglrcwtoorren") {
    ".togglrc" = {
      source = "/tmp/togglrcwtoorren";
    };
#    ".config/spotify/prefs" = {
#      source = "/tmp/spotifywto";
#    };
    ".config/attic/config.toml" = {
      source = "/tmp/atticwto";
    };
    ".config/openvpn/lobos.ovpn" = {
      source = "/data/agenix/kar01-lobos.ovpn";
    };

};
}

