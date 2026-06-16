{ ... }:

{
  services.swaync = {
    enable = true;
    settings = {
      positionX = "right";
      positionY = "top";
      layer = "overlay";
      control-center-layer = "overlay";
      layer-shell = true;
      cssPriority = "application";
      control-center-margin-top = 10;
      control-center-margin-bottom = 10;
      control-center-margin-right = 10;
      control-center-margin-left = 0;
      notification-2fa-action = true;
      notification-inline-replies = false;
      fit-to-screen = false;
      control-center-width = 400;
      control-center-height = 600;
      notification-window-width = 400;
      timeout = 5;
      timeout-low = 2;
      timeout-critical = 0;
      default-timeout = 5;
      hide-on-clear = false;
      hide-on-action = true;
      keyboard-shortcuts = true;
      image-visibility = "when-available";
      transition-time = 200;
      widgets = [ "inhibitors" "title" "dnd" "notifications" ];
      widget-config = {
        inhibitors = {
          text = "Inhibitors";
          button-text = "Clear All";
          clear-all-button = true;
        };
        title = {
          text = "Notificaties";
          clear-all-button = true;
          button-text = "Alles wissen";
        };
        dnd = {
          text = "Niet storen";
        };
        notifications = {
          notification-icon-size = 48;
          notification-body-image-height = 100;
          notification-body-image-width = 200;
        };
      };
    };

    style = ''
      * {
        font-family: "JetBrains Mono", monospace;
        font-size: 13px;
      }

      .notification-row {
        outline: none;
      }

      .notification-row:focus,
      .notification-row:hover {
        background: rgba(131, 165, 152, 0.1);
      }

      .notification {
        background: #1d2021;
        border: 2px solid #83a598;
        border-radius: 4px;
        margin: 4px;
        padding: 8px;
        color: #d5c4a1;
      }

      .notification-content {
        background: transparent;
        padding: 4px;
      }

      .notification-default-action {
        background: transparent;
        color: #d5c4a1;
      }

      .notification-default-action:hover {
        background: rgba(131, 165, 152, 0.1);
      }

      .summary {
        font-weight: bold;
        color: #d5c4a1;
      }

      .body {
        color: #bdae93;
      }

      .time {
        color: #665c54;
        font-size: 10px;
      }

      .close-button {
        background: transparent;
        color: #fb4934;
        border: none;
        padding: 2px;
      }

      .close-button:hover {
        background: rgba(251, 73, 52, 0.2);
      }

      .control-center {
        background: #1d2021;
        border: 2px solid #83a598;
        border-radius: 4px;
        color: #d5c4a1;
        padding: 4px;
      }

      .control-center-list {
        background: transparent;
      }

      .floating-notifications {
        background: transparent;
      }

      .blank-window {
        background: transparent;
      }

      .widget-title {
        color: #fabd2f;
        font-weight: bold;
        font-size: 14px;
        padding: 8px;
      }

      .widget-title > button {
        background: #504945;
        border: none;
        border-radius: 4px;
        color: #d5c4a1;
        padding: 4px 8px;
      }

      .widget-title > button:hover {
        background: #665c54;
      }

      .widget-dnd {
        padding: 8px;
        color: #d5c4a1;
      }

      .widget-dnd > switch {
        background: #504945;
        border: none;
        border-radius: 10px;
      }

      .widget-dnd > switch:checked {
        background: #83a598;
      }

      .notification.critical {
        border: 3px solid #fb4934;
      }

      .notification-group.critical {
        border: 3px solid #fb4934;
      }
    '';
  };
}
