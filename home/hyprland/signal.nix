{ ... }:

# Signal-desktop start onder Wayland zónder tray-icoon: de app detecteert geen
# StatusNotifierWatcher en forceert dan `DoNotUseSystemTray` in
# ~/.config/Signal/ephemeral.json (het in-app-vinkje "Minimize to system tray"
# doet daardoor niets en onze edits worden bij afsluiten teruggezet). De vlag
# `--use-tray-icon` dwingt tray-ondersteuning af, waardoor de instelling blijft
# staan en het icoon in wayle's systray verschijnt (net als Telegram/Teams/Slack).
#
# Deze desktop-entry heet exact `signal` en schaduwt daarmee de gepackte
# `signal.desktop` uit environment.systemPackages: ~/.local/share/applications
# staat vóór /run/current-system/sw/share/applications in XDG_DATA_DIRS, dus
# walker/launchers pakken deze versie.

{
  xdg.desktopEntries.signal = {
    name = "Signal";
    genericName = "Private Messenger";
    comment = "Private messaging from your desktop";
    exec = "signal-desktop --use-tray-icon %U";
    icon = "signal-desktop";
    terminal = false;
    type = "Application";
    categories = [ "Network" "InstantMessaging" "Chat" ];
    mimeType = [ "x-scheme-handler/sgnl" "x-scheme-handler/signalcaptcha" ];
    settings = {
      StartupWMClass = "signal";
    };
  };
}
