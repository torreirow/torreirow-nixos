{ lib, unstable, ... }:

# Alleen de machine-learningdienst van Immich, voor Immich op malandro (zie docs/immich.md).
# De Celeron J3455 van malandro heeft geen AVX; deze host wel. Malandro gebruikt deze dienst via
# de Nebula-mesh (http://10.77.0.2:3003); de Nebula-firewall laat poort 3003 alleen voor
# malandro door (modules/nebula.nix), de host-firewall houdt hem dicht op wifi/LAN.
#
# Eigen unit i.p.v. services.immich.machine-learning: die zit onder services.immich.enable en
# zou ook immich-server, PostgreSQL en redis meebrengen. De unit volgt de upstream-module.

let
  port = 3003;
  # Zelfde versie als immich-server op malandro (die komt ook uit unstable).
  package = unstable.immich.machine-learning;
  cacheDir = "/var/cache/immich-ml";
in
{
  systemd.services.immich-machine-learning = {
    description = "Immich machine learning (voor Immich op malandro)";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      MACHINE_LEARNING_WORKERS = "1";
      MACHINE_LEARNING_WORKER_TIMEOUT = "120";
      # Modellen na 10 minuten zonder werk uit het geheugen.
      MACHINE_LEARNING_MODEL_TTL = "600";
      MACHINE_LEARNING_CACHE_FOLDER = cacheDir;
      XDG_CACHE_HOME = cacheDir;
      # Gunicorn zet zijn control-socket in XDG_RUNTIME_DIR; anders in een niet-schrijfbare map.
      XDG_RUNTIME_DIR = "/run/immich-ml";
      # Alle adressen: binden op het Nebula-IP faalt zolang de tun er nog niet is.
      IMMICH_HOST = "0.0.0.0";
      IMMICH_PORT = toString port;
    };
    serviceConfig = {
      ExecStart = lib.getExe package;
      DynamicUser = true;
      CacheDirectory = "immich-ml";
      RuntimeDirectory = "immich-ml";
      WorkingDirectory = cacheDir;
      Restart = "on-failure";
      # Een batch na een grote upload mag de laptop niet traag maken (zie ook throttle-nix-builds).
      Nice = 15;
      CPUWeight = 20;
      IOSchedulingClass = "idle";

      PrivateTmp = true;
      PrivateDevices = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      NoNewPrivileges = true;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
      UMask = "0077";
    };
  };
}
