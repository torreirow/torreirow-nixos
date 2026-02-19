{ config, lib, pkgs, agenix, ... }:

{

services.nginx = {
  enable = true;

  virtualHosts."status.toorren.net" = {
    locations."/endpoints" = {
      extraConfig = ''
        gzip off;
        include ${pkgs.nginx}/conf/fastcgi_params;
        fastcgi_pass unix:${config.services.fcgiwrap.socketAddress};
        fastcgi_param SCRIPT_FILENAME /usr/local/bin/list-endpoints.sh;
      '';
    };
  };
};

services.fcgiwrap.enable = true;

}
