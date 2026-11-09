{ writeShellApplication, makeDesktopItem, symlinkJoin, pipewire, jq, libnotify, sox, coreutils, gnugrep }:

let
  podrec = writeShellApplication {
    name = "podrec";
    runtimeInputs = [ pipewire jq libnotify sox coreutils gnugrep ];
    text = builtins.readFile ./podrec.sh;
  };

  item = action: label: icon: makeDesktopItem {
    name = "podrec-${action}";
    desktopName = label;
    exec = "${podrec}/bin/podrec ${action}";
    inherit icon;
    categories = [ "AudioVideo" "Audio" ];
  };
in
symlinkJoin {
  name = "podrec";
  paths = [
    podrec
    (item "start" "Podcast opname starten" "media-record")
    (item "stop" "Podcast opname stoppen" "media-playback-stop")
  ];
}
