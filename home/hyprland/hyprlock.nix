{ config, lib, pkgs, ... }:

let
  # Roterende lock-teksten: per vergrendeling één willekeurige placeholder + fail_text.
  # hyprlock leest die alleen bij de start, dus "rouleren" = het gesourcede bestand vóór de volgende lock
  # herschrijven (HM-activatie + hypridle on_unlock_cmd). hyprlock vult $USER en $ATTEMPTS zelf in.
  # Geen '#' gebruiken: dat is commentaar in hyprlang.
  placeholders = [
    "[sudo] password for $USER:"
    "Enter passphrase for key '$USER@lobos':"
    "Authentication required · password or fingerprint"
    "Session locked · awaiting credentials"
    "nixos-rebuild: authentication required"
    "Verifying identity before switch..."
    "Zero trust: authenticate to continue"
    "Credentials required to resume session"
  ];
  fails = [
    "Permission denied (publickey,password,fingerprint)."
    "Authentication failed (attempt $ATTEMPTS)"
    "sudo: $ATTEMPTS incorrect password attempt(s)"
    "error: hash mismatch in supplied credentials"
    "403 Forbidden · attempt $ATTEMPTS logged"
    "PAM: authentication failure"
    "error: builder for 'unlock.drv' failed with exit code 1"
    "Access denied. Incident logged."
  ];

  textsFile = "${config.xdg.stateHome}/hyprlock/texts.conf";

  rotateTexts = pkgs.writeShellApplication {
    name = "hyprlock-rotate-texts";
    runtimeInputs = [ pkgs.coreutils ];
    # SC2016: $LOCK_* moet letterlijk in het bestand komen (hyprlang-variabelen), niet door bash ge-expand.
    excludeShellChecks = [ "SC2016" ];
    text = ''
      dir=$(dirname "${textsFile}")
      mkdir -p "$dir"
      p=$(shuf -n1 ${pkgs.writeText "hyprlock-placeholders" (lib.concatLines placeholders)})
      f=$(shuf -n1 ${pkgs.writeText "hyprlock-fails" (lib.concatLines fails)})
      tmp=$(mktemp "$dir/.texts.XXXXXX")
      printf '$LOCK_PLACEHOLDER = %s\n$LOCK_FAIL = %s\n' "$p" "$f" > "$tmp"
      mv -f "$tmp" "${textsFile}"
    '';
  };
in

{
  # Bestand moet er altijd zijn vóór de eerste lock; ontbreekt het toch, dan negeert hyprlock de fout.
  home.activation.hyprlockTexts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${rotateTexts}/bin/hyprlock-rotate-texts
  '';

  # Volgende lock een nieuwe tekst. Hangt aan Hyprland's lock-notificatie: geldt voor alle lock-routes.
  services.hypridle.settings.general.on_unlock_cmd = "${rotateTexts}/bin/hyprlock-rotate-texts";

  programs.hyprlock = {
    enable = true;

    # "source" erbij zodat het tekstbestand vóór de widgets geparsed wordt (variabelen eerst definiëren).
    importantPrefixes = [ "$" "bezier" "monitor" "size" "source" ];

    settings = {
      source = textsFile;

      general = {
        disable_loading_bar = true;
        no_fade_in = false;
        hide_cursor = true;
        ignore_empty_input = true;
      };

      # Vingerafdruk via hyprlock's eigen D-Bus-pad naar fprintd, parallel aan PAM (wachtwoord).
      # Bewust stil: geen $FPRINTPROMPT-label. PAM zelf blijft zonder fprintd (hosts/lobos/hyprland.nix).
      auth = {
        "pam:enabled" = true;
        "fingerprint:enabled" = true;
      };

      background = [{
        monitor = "";
        path = "screenshot";
        blur_passes = 1;
        blur_size = 8;
      }];

      input-field = [{
        monitor = "";
        size = "600, 80";
        position = "0, 0";
        halign = "center";
        valign = "center";

        inner_color = "rgb(504945)";    # Gruvbox bg2
        outer_color = "rgb(d5c4a1)";    # Gruvbox fg1
        outline_thickness = 4;

        font_family = "JetBrains Mono";
        font_size = 24;
        font_color = "rgb(d5c4a1)";     # Gruvbox fg1

        placeholder_color = "rgb(bdae93)"; # Gruvbox fg4
        placeholder_text = "$LOCK_PLACEHOLDER";
        check_color = "rgb(b8bb26)";    # Gruvbox green
        fail_text = "$LOCK_FAIL";

        rounding = 4;
        shadow_passes = 0;
        fade_on_empty = false;
        dots_center = true;
      }];

      label = [{
        monitor = "";
        text = ''cmd[update:1000] echo "$(date +"%H:%M")"'';
        color = "rgb(d5c4a1)";          # Gruvbox fg1
        font_size = 64;
        font_family = "JetBrains Mono";
        position = "0, 120";
        halign = "center";
        valign = "center";
      }
      {
        # Statisch vingerafdruk-icoon (nf-md-fingerprint, U+F0237) onder het invoerveld als hint; geen statustekst.
        monitor = "";
        text = "󰈷";
        color = "rgb(bdae93)";          # Gruvbox fg4
        font_size = 48;
        font_family = "JetBrainsMono Nerd Font";
        position = "0, -110";
        halign = "center";
        valign = "center";
      }];
    };
  };
}
