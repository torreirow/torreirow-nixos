{config, lib, pkgs,  agenix, ... }:
{

  age = {
    identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
      togglrc = {
        file = ../../secrets/togglwtoorren.age;
        path = "/tmp/togglrcwtoorren";
        owner = "root";
        group = "wheel";
        mode = "0760";
      };
#      loboskey = {
#        file = ../../secrets/loboskey.age;
#        path = "/tmp/loboskey";
#        owner = "wtoorren";
#        group = "wtoorren";
#        mode = "600";
#      };
      spotifywto = {
        file = ../../secrets/spotifywto.age;
        path = "/home/wtoorren/.config/spotify/prefs";
        owner = "wtoorren";
        group = "nogroup";
        mode = "0400";
      };
      atticwto = {
        file = ../../secrets/atticwto.age;
        path = "/tmp/atticwto";
        owner = "wtoorren";
        group = "nogroup";
        mode = "0400";
      };
     update_latop = {
        file = ../../secrets/update_laptop.age;
        path = "/data/scripts/update_laptop.sh";
        owner = "root";
        group = "root";
        mode = "0400";
      };
     kar01_vpn_lobos = {
       file = ../../secrets/kar01-lobos-ovpn.age;
       path = "/data/agenix/kar01-lobos.ovpn";
       owner = "wtoorren";
       group = "nogroup";
       mode = "0400";
      };
};
  };


}
