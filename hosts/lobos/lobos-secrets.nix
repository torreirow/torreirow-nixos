{config, lib, pkgs,  agenix, ... }:
{

  age = {
    identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
      togglrc = {
        file = ../../secrets/togglwtoorren.age;
        path = "/tmp/togglrcwtoorren";
        owner = "root";
        group = "users";
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
        path = "/tmp/spotifywto";
        owner = "wtoorren";
        group = "users";
        mode = "600";
      };
      atticwto = {
        file = ../../secrets/atticwto.age;
        path = "/tmp/atticwto";
        owner = "wtoorren";
        group = "users";
        mode = "600";
      };
     };
  };


}
