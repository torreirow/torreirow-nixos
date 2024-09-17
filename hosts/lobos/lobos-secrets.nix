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
    };
  };


}
