{config, lib, pkgs,  agenix, toggl-cli, ... }:

{
  environment.systemPackages = with pkgs; [
(python311.withPackages(ps: with ps; [ 
  requests
  buienradar
  lxml
  python-telegram-bot
  pytz
]))
   python311Packages.toggl-cli
  ];

}
