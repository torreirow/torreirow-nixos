# Dindoa-wedstrijdagenda's, gegenereerd door de module uit github:torreirow/dindoa.
# Het resultaat staat op https://toorren.net/dindoa/; een Apps Script zet de feed
# elk uur over in de eigen Google-agenda (UID-match, zie de dindoa-README).
{ ... }:
{
  services.dindoa = {
    outputDir = "/var/www/toorren.net/dindoa";
    group = "users"; # handmatig een bestand neerzetten blijft mogelijk
    calendars.j4 = {
      team = "j4";
      email = "wvdtoorren@gmail.com";
    };
  };
}
