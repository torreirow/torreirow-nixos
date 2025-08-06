{ pkgs, ... }:

let
  addons = pkgs.nur.repos.rycee.firefox-addons;
in
{
  programs.google-chrome.enable = true;

  programs.librewolf = {
    enable = true;
    policies = {
      ExtensionSettings = with builtins;
        let extension = shortId: uuid: {
          name = uuid;
          value = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/${shortId}/latest.xpi";
            installation_mode = "normal_installed";
          };
        };
        in listToAttrs [
          (extension "ublock-origin" "uBlock0@raymondhill.net")
          (extension "aws-role-switch" "{31f7b254-7ac9-4f3a-ae3c-ef67ea153e4a}")
          (extension "sponserblock" "{31f7b254-7ac9-4f3a-ae3c-ef67ea153e4a}")
        ];
      BookmarksToolbar = "newtab";
    };
    # LibreWolf supports language packs generally in the same way as Firefox,
    # but as of 24.05 you set language via the browser itself. You can try:
    languagePacks = [
      "en-US"
      "nl"
    ];
  };
}

