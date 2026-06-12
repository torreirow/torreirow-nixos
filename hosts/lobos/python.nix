{config, lib, pkgs,  agenix, ... }:

{
  environment.systemPackages = with pkgs; [
    zstd
    (python312.withPackages(ps: with ps; [
  buienradar
  icalendar
  icloudpd
  ics
  lxml
  numpy
  openpyxl
 # opsgenie-sdk
  pandas
  pytz
  pyyaml
  requests
  flake8
  prometheus-client

]))
  ];

}
