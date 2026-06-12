{config, lib, pkgs,  agenix, ... }:

{
  environment.systemPackages = with pkgs; [
    zstd
    (python3.withPackages(ps: with ps; [
  buienradar
  icalendar
  icloudpd
  ics
  lxml
  numpy
  openpyxl
  pandas
#  python-telegram-bot
  pytz
  pyyaml
  requests

]))
  ];

}
