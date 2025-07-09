{ config, pkgs,... }:

{

services.onlyoffice = {
  enable = true;
  hostname = "localhost";
};

}
