{ config, pkgs, ... }:

{
	services.nfs.server.enable = true;
	environment.etc."exports-dir".source = "/data";
	services.nfs.server.exports = ''
					 /data 192.168.2.0/24(rw,sync,no_subtree_check)
	'';
	services.nfs.settings = {
		nfsd.udp = false;
		nfsd.vers3 = false;
		nfsd.vers4 = true;
		nfsd."vers4.0" = false;
		nfsd."vers4.1" = false;
		nfsd."vers4.2" = true;
	};
}
