{config, lib, pkgs,  agenix, ... }:
{
  age.secrets.monitrc = {
    file = ../secrets/monitrc.age;
    path = "~/togglrc";
  };
}
