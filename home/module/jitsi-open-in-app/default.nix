# Home-manager module: legt het Tampermonkey-userscript neer dat
# https://meet.jit.si/<kamer> omzet naar jitsi-meet://meet.jit.si/<kamer>,
# zodat een link uit Outlook Web of Slack in jitsi-meet-electron opent in
# plaats van in een Firefox-tab.
#
# Zelfde patroon als home/module/wake-bobadela1: bron in de repo, deploy via
# home.file. Tampermonkey zelf staat al declaratief in de Firefox-policy
# (hosts/lobos/programs.nix); de bijbehorende Handlers-policy voor het
# jitsi-meet://-schema staat daar ook.
#
# LET OP: het script moet éénmalig handmatig in Tampermonkey geïnstalleerd
# worden -- userscripts leven in de extensie-opslag van de browser en zijn
# niet declaratief te plaatsen. Zie README.md.
{ config, lib, pkgs, ... }:

let
  # @HOME@ in de @downloadURL/@updateURL-headers invullen, zodat Tampermonkey
  # updates rechtstreeks uit dit bestand kan trekken na een rebuild.
  script = builtins.replaceStrings
    [ "@HOME@" ]
    [ config.home.homeDirectory ]
    (builtins.readFile ./jitsi-open-in-app.user.js);
in
{
  home.file.".local/share/userscripts/jitsi-open-in-app.user.js".text = script;
}
