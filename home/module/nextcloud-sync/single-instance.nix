# nextcloud-client met een single-instance-slot op de GUI (`bin/nextcloud`).
#
# Waarom: op 2026-10-01 draaiden er twee GUI-clients naast elkaar -- één uit de
# XDG-autostart (`nextcloud --background`) en één die 's ochtends via de
# launcher was gestart. De ingebouwde single-instance-check van de client liet
# dat gewoon toe. De eerste hield de sync-journal (`~/Documents/.sync_*.db`)
# exclusief vast, dus de tweede kreeg `database is locked`, zag zijn hele
# geschiedenis als leeg en ging 300+ bestanden opnieuw "syncen" (metadata +
# conflict-checks; gelukkig zonder transfers of conflict-kopieën).
#
# Hoe: alle startpaden (autostart, launcher-.desktop, handmatig) roepen
# `nextcloud` via PATH aan en komen dus langs deze wrapper. Die pakt een flock
# op $XDG_RUNTIME_DIR/nextcloud-gui.lock en houdt hem via fd 9 vast zolang de
# client draait. Is het slot bezet, dan start er niets en krijg je een melding.
#
# `--quit` mag wél door (de "Quit"-actie van de .desktop): die praat met de
# draaiende instantie en start zelf geen sync. `nextcloudcmd` blijft ongemoeid.
{ symlinkJoin, writeShellScript, nextcloud-client, util-linux, libnotify }:

let
  guard = writeShellScript "nextcloud-single-instance" ''
    if [ "''${1:-}" = "--quit" ]; then
      exec ${nextcloud-client}/bin/nextcloud "$@"
    fi

    lock="''${XDG_RUNTIME_DIR:-/tmp}/nextcloud-gui.lock"
    exec 9>"$lock"
    if ! ${util-linux}/bin/flock -n 9; then
      msg="Nextcloud draait al; tweede instantie niet gestart."
      echo "$msg" >&2
      ${libnotify}/bin/notify-send -a Nextcloud "Nextcloud" "$msg" 2>/dev/null || true
      exit 0
    fi

    exec ${nextcloud-client}/bin/nextcloud "$@"
  '';
in
symlinkJoin {
  name = "nextcloud-client-single-instance-${nextcloud-client.version}";
  paths = [ nextcloud-client ];
  postBuild = ''
    rm $out/bin/nextcloud
    ln -s ${guard} $out/bin/nextcloud
  '';
  inherit (nextcloud-client) meta;
}
