{config, lib, pkgs,  agenix, toggl-cli, ... }:

{
  environment.systemPackages = with pkgs; [
    (python311.withPackages(ps: with ps; [ 
  requests
  pandas
  buienradar
  lxml
  python-telegram-bot
  pytz
  opsgenie-sdk
  pyyaml
  ics
  icloudpd
]))
python311Packages.toggl-cli
  ];

}
