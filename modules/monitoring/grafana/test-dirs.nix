# test-dirs.nix
let
    dashboardsDir = ./dashboards;
      customerDirs = builtins.filter (name:
          (builtins.readDir dashboardsDir)."${name}" == "directory"
            ) (builtins.attrNames (builtins.readDir dashboardsDir));
in
  customerDirs
