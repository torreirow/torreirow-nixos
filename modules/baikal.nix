{ config, pkgs, ... }:

{
  virtualisation.oci-containers.containers.infcloud = {
    image = "ckulka/infcloud:experimental";
    autoStart = true;

    ports = [
      "127.0.0.1:8082:80"
    ];
  };

  virtualisation.oci-containers.containers.baikal = {
    image = "ckulka/baikal:nginx";
    autoStart = true;

    ports = [
      "127.0.0.1:8081:80"
    ];

    volumes = [
      "/var/lib/baikal/config:/var/www/baikal/config"
      "/var/lib/baikal/data:/var/www/baikal/Specific"
    ];
  };

  # Zorg dat de directories bestaan
  systemd.tmpfiles.rules = [
    "d /var/lib/baikal 0755 root root -"
    "d /var/lib/baikal/config 0755 root root -"
    "d /var/lib/baikal/data 0755 root root -"
  ];

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts."contacts.toorren.net" = {
      enableACME = true;
      forceSSL = true;

      locations."/" = {
        proxyPass = "http://127.0.0.1:8082";
        proxyWebsockets = true;
      };
    };

    virtualHosts."adresses.toorren.net" = {
      enableACME = true;
      forceSSL = true;

      locations."/" = {
        proxyPass = "http://127.0.0.1:8081";
        proxyWebsockets = false;

        extraConfig = ''
          dav_methods     PUT DELETE MKCOL COPY MOVE;
          dav_ext_methods PROPFIND OPTIONS;
          rewrite         ^/.well-known/caldav /cal.php redirect;
          rewrite         ^/.well-known/carddav /card.php redirect;
        '';
      };
    };
  };
}

