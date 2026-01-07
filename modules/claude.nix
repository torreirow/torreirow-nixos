{ config, lib, pkgs, ... }:

{
age.secrets = {
  claude = {
    path = "/tmp/claude.env";
    owner = "wtoorren";
    mode = "0400";
    file = ../secrets/claude.age;
  };
};
}

