{ config, lib, pkgs, ... }:

# Haalt ML-werk van Immich in als de ML-dienst op lobos (modules/immich-ml.nix) weer bereikbaar
# is: uploads terwijl lobos uit was krijgen anders geen zoekdata en gezichten. Een timer pingt
# de ML-dienst en start dan bij Immich de "Missing"-jobs (smartSearch, faceDetection). Zie
# docs/immich.md.
#
# De API-sleutel (admin, alleen recht `job.create`) maakt de beheerder zelf in Immich en zet hem
# in secrets/immich-ml-catchup-key.age. Zolang dat bestand er niet is, staat de timer uit.

let
  keyFile = ../../secrets/immich-ml-catchup-key.age;
  haveKey = builtins.pathExists keyFile;
  catchup = pkgs.callPackage ./package.nix { };
in
lib.mkMerge [
  {
    warnings = lib.optional (!haveKey)
      "immich-ml-catchup: secrets/immich-ml-catchup-key.age ontbreekt; de inhaal-timer staat uit (zie docs/immich.md).";
  }

  (lib.mkIf haveKey {
    age.secrets.immich-ml-catchup-key = {
      file = keyFile;
      mode = "0400"; # gelezen door systemd (LoadCredential), niet door de dienst-user
    };

    systemd.services.immich-ml-catchup = {
      description = "Immich: ML-jobs inhalen als ML op lobos bereikbaar is";
      after = [ "immich-server.service" "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe catchup;
        DynamicUser = true;
        StateDirectory = "immich-ml-catchup";
        Environment = [ "STATE_DIR=/var/lib/immich-ml-catchup" ];
        LoadCredential = [ "api-key:${config.age.secrets.immich-ml-catchup-key.path}" ];
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    };

    systemd.timers.immich-ml-catchup = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "10min";
      };
    };
  })
]
