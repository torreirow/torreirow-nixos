{ config, pkgs, ... }:

# Read-only JuiceFS-mount van het Nextcloud-datavolume op malandro.
#
# Het volume zelf leeft op bobadela1 (data in s3://wto-s3-bucket/juicefs/,
# metadata in PostgreSQL op bobadela1). Malandro mount HETZELFDE volume read-only
# tegen bobadela1's live metadata, zodat je hier de Nextcloud-bestanden kunt lezen
# (bv. voor backup/processing) zonder de live data te kunnen wijzigen.
#
# Toegang: de volume-root is 0750 met groep gid 1 (= wheel op malandro), dus
# wheel-leden kunnen lezen zonder sudo. Zie hosts/bobadela1/README.md.
#
# Let op: deze mount hangt aan bobadela1 (postgres) + de LAN. Valt bobadela1 weg,
# dan stalt de mount; Restart=on-failure haalt 'm terug zodra bobadela1 er weer is.

let
  metaUrl = "postgres://juicefs@192.168.2.67:5432/juicefs_meta";
  mountPoint = "/data/juicefs-nextcloud";
  cacheDir = "/var/cache/juicefs-nextcloud";
in
{
  # Env met ACCESS_KEY/SECRET_KEY/META_PASSWORD/JFS_RSA_PASSPHRASE (juicefs leest deze).
  age.secrets.juicefs-malandro-env = {
    file = ../secrets/juicefs-malandro-env.age;
    path = "/run/agenix/juicefs-malandro-env";
    mode = "0400";
  };

  environment.systemPackages = [ pkgs.juicefs ];

  systemd.tmpfiles.rules = [
    "d ${mountPoint} 0755 root root -"
    "d ${cacheDir} 0700 root root -"
  ];

  systemd.services.juicefs-nextcloud-ro = {
    description = "JuiceFS read-only mount van de Nextcloud-data (S3 + bobadela1-metadata)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      EnvironmentFile = "/run/agenix/juicefs-malandro-env";
      ExecStart =
        "${pkgs.juicefs}/bin/juicefs mount --read-only "
        + "${metaUrl} ${mountPoint} "
        + "--cache-dir ${cacheDir} --cache-size 5120 --no-bgjob -o allow_other";
      ExecStop = "${pkgs.util-linux}/bin/umount ${mountPoint}";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };
}
