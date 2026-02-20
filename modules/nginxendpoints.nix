{ pkgs, config, agenix... }:

{

      };
e.secrets.nginxendpoints-script = {
    file = ../secrets/nginxendpoints.age;
    path = "/run/agenix/list-endpoints.sh";
    owner = "nginx";
    group = "nginx";
    mode = "0666";

  };

  services.nginx = {
    forceSSL = true;
    useACMEHost = "toorren.net";

    virtualHosts."status.toorren.net" = {
      locations."/endpoints" = {
        extraConfig = ''
          gzip off;
          include ${pkgs.nginx}/conf/fastcgi_params;
          fastcgi_pass unix:${config.services.fcgiwrap.socketAddress};
          fastcgi_param SCRIPT_FILENAME /run/agenix/list-endpoints.sh;
        '';
      };
    };
  };

  services.fcgiwrap.enable = true;

}
