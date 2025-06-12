{ config, pkgs,... }:

{
	environment.systemPackages = with pkgs; [
		teamviewer
	];

	services.teamviewer.enable = true;

	systemd.services.teamviewerd = {
		enable = true;
		wantedBy = [ "multi-user.target" ];
	};

}
