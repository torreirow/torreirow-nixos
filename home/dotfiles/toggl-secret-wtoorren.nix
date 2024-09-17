{ config, pkgs, lib, ... }:
{
  home.file = lib.mkIf (builtins.pathExists "/tmp/togglrcwtoorren") {
    ".togglrc" = {
      source = "/tmp/togglrcwtoorren";
    };
  };
}

