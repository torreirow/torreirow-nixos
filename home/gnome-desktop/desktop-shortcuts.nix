{ ... }:

{
  dconf.settings = {
    "/" = {
      animate-appicon-hover = false;
      animate-appicon-hover-animation-extent = builtins.toJSON { RIPPLE = 4; PLANK = 4; SIMPLE = 1; };
      animate-show-apps = false;
      appicon-margin = 4;
      appicon-padding = 8;
      appicon-style = "NORMAL";
      available-monitors = [ 0 ];
      context-menu-entries = builtins.toJSON [
        { title = "Terminal"; cmd = "TERMINALSETTINGS"; }
        { title = "System monitor"; cmd = "gnome-system-monitor"; }
        { title = "Files"; cmd = "nautilus"; }
        { title = "Extensions"; cmd = "gnome-extensions-app"; }
      ];
      dot-color-override = false;
      dot-position = "TOP";
      dot-style-focused = "DOTS";
      dot-style-unfocused = "DOTS";
      extension-version = 68;

			"org/gnome/shell/favorite-apps" = [
				"org.gnome.Terminal.desktop"
				# eventueel meer .desktop-bestanden
			];
      global-border-radius = 1;
      group-apps = true;
      hide-overview-on-startup = false;
      highlight-appicon-hover = true;
      hot-keys = false;
      hotkeys-overlay-combo = "TEMPORARILY";
      intellihide = false;
      isolate-monitors = false;
      isolate-workspaces = true;
      leftbox-padding = -1;
      multi-monitor = true;
      multi-monitors = true;
      overview-click-to-exit = false;
      panel-anchors = builtins.toJSON { "0" = "END"; };
      panel-corner-radius = 0;
      panel-element-positions = builtins.toJSON {
        "0" = [
          { element = "dateMenu"; visible = true; position = "stackedTL"; }
          { element = "showAppsButton"; visible = false; position = "stackedTL"; }
          { element = "activitiesButton"; visible = false; position = "stackedTL"; }
          { element = "leftBox"; visible = true; position = "stackedTL"; }
          { element = "taskbar"; visible = true; position = "centerMonitor"; }
          { element = "centerBox"; visible = true; position = "stackedBR"; }
          { element = "rightBox"; visible = true; position = "stackedBR"; }
          { element = "systemMenu"; visible = true; position = "stackedBR"; }
          { element = "desktopButton"; visible = false; position = "stackedBR"; }
        ];
      };
      panel-element-positions-monitors-sync = true;
      panel-element-spacing = 4;
      panel-length-percent = 100.0;
      panel-lengths = builtins.toJSON {
        "AUO-0x00000000" = 100;
        "SAM-H4TW702500" = 100;
      };
      panel-position = "TOP";
      panel-positions = builtins.toJSON {
        "AUO-0x00000000" = "TOP";
        "SAM-H4TW702527" = "TOP";
        "MSI-CC6Q012200296" = "TOP";
        "SAM-H4TW702492" = "TOP";
        "SAM-H4TW702500" = "TOP";
        "SAM-H4TW702488" = "TOP";
        "SAM-H4TW302454" = "TOP";
      };
      panel-side-margins = 4;
      panel-size = 28;
      panel-sizes = builtins.toJSON {
        "AUO-0x00000000" = 39;
        "SAM-H4TW702500" = 39;
      };
      prefs-opened = true;
      primary-monitor = 0;
      progress-show-count = true;
      show-apps-icon = false;
      show-apps-icon-file = "";
      show-apps-icon-side-padding = 8;
      show-apps-override-escape = false;
      show-favorites = false;
      show-favorites-all-monitors = false;
      show-running-apps = true;
      show-showdesktop-hover = true;
      show-tooltip = false;
      show-window-previews = true;
      showdesktop-button-width = 10;
      status-icon-padding = -1;
      stockgs-keep-dash = false;
      stockgs-keep-top-panel = false;
      trans-bg-color = "#000000";
      trans-dynamic-behavior = "MAXIMIZED_WINDOWS";
      trans-panel-opacity = 1.0;
      trans-use-custom-bg = false;
      trans-use-custom-opacity = false;
      trans-use-dynamic-opacity = false;
      transparency-mode = "DYNAMIC";
      tray-padding = -1;
      window-preview-title-position = "TOP";
    };
  };
}

