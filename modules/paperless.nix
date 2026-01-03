{ config, pkgs, lib, agenix, ... }:
{
	services.nginx.virtualHosts."docs.toorren.net" = {
		enableACME = true;
		forceSSL = true;
		locations."/" = {
			proxyPass = "http://127.0.0.1:8181";
			proxyWebsockets = false;
		};
  };

  networking.firewall.interfaces.docker0.allowedTCPPorts = [ 5432 ];
}
