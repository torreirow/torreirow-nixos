{ config, lib, pkgs, ... }:

# Fotodienst voor de meet-ups van cckafe.com: haalt per album de metadata uit
# Immich op en schrijft alleen een manifest naar /var/lib/cckafe-photos. De
# foto's zelf blijven in Immich; nginx proxyt ze op /immich/<asset-id>.webp
# (zie modules/cckafe.nix). Zie docs/cckafe-photos.md.
#
# De albums krijgen GEEN share-link: ze worden alleen met de API-sleutel
# opgehaald, dus er bestaat geen openbare Immich-URL die naar een meet-upalbum
# wijst. De sleutel komt uit secrets/immich-cckafe-photos-key.age en gaat via
# LoadCredential, zodat hij niet in de proceslijst staat.
#
# De lijst met meet-ups en hun albumnamen komt uit meetups/index.txt in de
# webroots van productie en test.
# Die schrijft de Hugo-build (repo cckafe-website); via HTTP is die file niet
# bereikbaar.
#
# De dienst bouwt de website niet; ./release.sh in de website-repo blijft de
# enige manier waarop de site zelf verandert.
let
  keyFile = ../../secrets/immich-cckafe-photos-key.age;
  haveKey = builtins.pathExists keyFile;
  fetch = pkgs.callPackage ./package.nix { };
in
lib.mkMerge [
  {
    warnings = lib.optional (!haveKey)
      "cckafe-photos: secrets/immich-cckafe-photos-key.age ontbreekt; de fotodienst staat uit (zie docs/cckafe-photos.md).";
  }

  (lib.mkIf haveKey {
    # Eigen systeemgebruiker, in de groep nginx zodat nginx de manifesten kan lezen.
    users.users.cckafe-photos = {
      isSystemUser = true;
      group = "nginx";
      description = "Fotodienst voor de meet-ups van cckafe.com";
    };

    age.secrets.immich-cckafe-photos-key = {
      file = keyFile;
      mode = "0400"; # gelezen door systemd (LoadCredential), niet door de dienst-user
    };

    systemd.services.cckafe-photos = {
      description = "cckafe.com: foto's van meet-ups ophalen uit Immich";
      after = [ "immich-server.service" "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe fetch;
        # De fotomap staat in /var/lib, niet in de webroot: release.sh doet
        # `rsync --delete` over de webroot en zou de foto's anders weghalen.
        #
        # StateDirectory laat systemd de map zelf aanmaken met de juiste eigenaar
        # (cckafe-photos:nginx) en zet hem automatisch op ReadWritePaths, ook onder
        # ProtectSystem=strict. Een tmpfiles-regel bleek niet betrouwbaar: de map
        # bestond dan wel, maar de dienst kon hem niet betreden ("mkdir: cannot
        # stat: Permission denied"). Met een vaste gebruiker (geen DynamicUser)
        # staat de map direct onder /var/lib en niet onder /var/lib/private, dus
        # nginx kan er via de groep bij.
        StateDirectory = "cckafe-photos";
        StateDirectoryMode = "0750";
        User = "cckafe-photos";
        Group = "nginx";
        UMask = "0027"; # bestanden 0640 cckafe-photos:nginx — leesbaar voor nginx
        Environment = [
          "PHOTOS_DIR=/var/lib/cckafe-photos"
          # Productie en test: een test-release schrijft de lijst alleen in de
          # test-webroot. De foto's zijn voor beide sites hetzelfde.
          # Scheidingsteken is ":" en niet een spatie: systemd splitst
          # Environment= op whitespace en zou het tweede pad als losse,
          # ongeldige toewijzing negeren.
          "MEETUPS_FILES=/var/www/cckafe.com/meetups/index.txt:/var/www/test.cckafe.com/meetups/index.txt"
        ];
        LoadCredential = [ "api-key:${config.age.secrets.immich-cckafe-photos-key.path}" ];
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    };

    systemd.timers.cckafe-photos = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "15min";
      };
    };
  })
]
