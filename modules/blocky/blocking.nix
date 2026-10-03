# Blocking-policy voor blocky, los van de service-infra (zie default.nix).
#
# Per groep gelden meerdere bronnen die blocky samenvoegt (union):
#   - declaratieve baseline (URL-lijsten en/of een repo-bestand in ./lists/, in git)
#   - een mutabel overlay-BESTAND op /data/external/blocky (sudo-bewerkbaar, live
#     herlaadbaar via `blocky-refresh`), plus een allowlist-overlay om live vrij te geven.
#
# LET OP: blocky accepteert als bron een los BESTAND, geen directory of glob (dat
# faalt met "is a directory" / "cannot open '*'"). Daarom één overlay-bestand per groep.
#
# `overlayGroups` wordt door default.nix gebruikt om de tmpfiles-bestanden te genereren.
{ overlayBase }:
let
  denyOverlay = group: "${overlayBase}/denylists.d/${group}.txt";
  allowOverlay = group: "${overlayBase}/allowlists.d/${group}.txt";
in
{
  # Groepen die een mutabele deny- + allow-overlay krijgen.
  overlayGroups = [ "ads" "Boaz" ];

  settings = {
    denylists = {
      ads = [
        # Baseline: externe lijsten (URL-bronnen).
        "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
        "https://v.firebog.net/hosts/AdguardDNS.txt"
        "https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt"
        # Baseline: eigen, met de hand beheerde domeinen (in git, platte tekst).
        ./lists/custom.txt
        # Overlay: live toe te voegen blokkades (één bestand), zonder rebuild.
        (denyOverlay "ads")
      ];
      # Boaz: youtube + tiktok (baseline in git) + overlay. Alleen actief binnen
      # het schedule hieronder (werkdagen 12:00-18:00) en alleen voor de Boaz-IP's.
      Boaz = [
        ./lists/boaz.txt
        (denyOverlay "Boaz")
      ];
    };

    # Allowlist-overlay: hiermee geef je domeinen live weer vrij voor de groep.
    allowlists = {
      ads = [ (allowOverlay "ads") ];
      Boaz = [ (allowOverlay "Boaz") ];
    };

    # Client → groep(en). Een IP met een eigen regel krijgt NIET meer de default,
    # daarom staat "ads" expliciet bij de Boaz-apparaten (zo houden ze ad-blocking).
    clientGroupsBlock = {
      default = [ "ads" ];
      "192.168.2.181" = [ "ads" "Boaz" ];
      "192.168.2.182" = [ "ads" "Boaz" ];
    };

    # Named schedule: werkdagen 12:00-18:00.
    schedules = {
      boaz-werkuren = {
        weekdays = [ "mon" "tue" "wed" "thu" "fri" ];
        start = "12:00";
        end = "18:00";
      };
    };

    # De Boaz-lijst is ALLEEN actief binnen boaz-werkuren (buiten die uren niets
    # geblokkeerd via Boaz). Lijsten zonder listSchedule (zoals ads) zijn altijd actief.
    listSchedules = {
      Boaz = [ "boaz-werkuren" ];
    };

    # Antwoord op een geblokkeerde query: NXDOMAIN ("site bestaat niet") i.p.v. 0.0.0.0.
    # Geeft een schonere browser-melding en geen hangende connectie. Globaal (ook ads).
    blockType = "nxDomain";
  };
}
