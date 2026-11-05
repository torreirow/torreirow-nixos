# AWS-deel van het wtoorren-admin-profiel. bmc en race staan er altijd; zonder credentials doen
# ze niets. De shell-wrappers verschijnen pas als ~/.aws/credentials op de host bestaat (runtime:
# Nix evalueert op lobos en ziet de doelhost niet). ~/.aws/config alleen bij aws.enable.
{ config, lib, pkgs, adminInputs, ... }@args:

let
  cfg = config.toorren.admin;
  system = pkgs.stdenv.hostPlatform.system;
  bmc = adminInputs.bmc.packages.${system}.bmc;
  race = adminInputs.race.packages.${system}.race;

  # Zelfde profielen als lobos; leest ~/.aws/managed_service_accounts.json (vraagt --impure).
  awsconf = import ../../awsconf.nix args;

  bmcConfig = {
    mfa = {
      enabled = true;
      totp_script = cfg.bmc.totpScript;
      profile_scripts = cfg.bmc.profileScripts;
      # bmc voert dit zonder shell uit met de code op stdin. tmux stuurt de buffer met OSC 52
      # door naar het clipboard van de terminal op lobos (set-clipboard on, home/tmux.nix).
      # Geen paste-commando: er is geen actief venster op een headless host.
      copy_command = "tmux load-buffer -w -";
      paste_command = "";
    };
  };
in
{
  imports = [ ../../custom_modules/awscli_custom.nix ];

  options.toorren.admin.bmc = {
    totpScript = lib.mkOption {
      type = lib.types.str;
      default = ''rbw code "Technative AWS (new)"'';
      description = "Commando dat de MFA-code voor bmc geeft.";
    };
    profileScripts = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "MFA-commando per bronprofiel; anders geldt totpScript.";
    };
  };

  config = lib.mkMerge [
    {
      home.packages = [ bmc race ];

      xdg.configFile."bmc/config.json".text = builtins.toJSON bmcConfig;

      programs.zsh.initContent = ''
        if [[ -f "$HOME/.aws/credentials" ]]; then
          bmc() {
            if [[ "$1" == "profsel" ]]; then
              eval "$(command bmc profsel "$@")"
            else
              command bmc "$@"
            fi
          }
          alias bmcp="bmc profsel -p technative"
          alias aws-switch="bmc profsel"
          alias tfplan="tfplan.sh"
          alias tfapply="tfapply.sh"
          alias tfbackend="tfbackend.sh"
        fi
      '';
    }

    (lib.mkIf cfg.aws.enable {
      inherit (awsconf) programs systemd;
    })
  ];
}
