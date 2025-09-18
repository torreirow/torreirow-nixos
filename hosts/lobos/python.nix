{config, lib, pkgs,  agenix, toggl-cli, ... }:

{
  environment.systemPackages = with pkgs; [
    zstd
    (python311.withPackages(ps: with ps; [ 
  buienradar
  icalendar
  icloudpd
  ics
  lxml
  numpy
  openpyxl
  opsgenie-sdk
  pandas
  python-telegram-bot
  pytz
  pyyaml
  requests
  flake8

]))
python311Packages.toggl-cli
  ];

}
