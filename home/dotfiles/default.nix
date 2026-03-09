{
  # Technative AWS Accounts JSON/NIX file

  home.file = {
    ".ohmyzsh-wouter" = {
      source = ./.ohmyzsh-wouter;
      recursive = true;
    };
    ".zsh/completions" = {
    source = ./.zsh/completions;
    recursive = true;
    };
    ".config/rbw/config.json" = {
      source = ./.config/rbw/config.json;
      recursive = true;
    };
    ".config/rbw-technative/config.json" = {
      source = ./.config/rbw-technative/config.json;
      recursive = true;
    };".config/smug" = {
      source = ./.config/smug;
      recursive = true;
    }; 
    ".vim" = {
      source = ./.vim;
      recursive = true;
    };
    ".vimrc" = { 
      source = ./.vimrc;
      recursive = false;
    };
    ".config/openvpn" = { 
      source = ./.config/openvpn;
      recursive = true;
    };
#    ".aws/managed_service_accounts.json" = {
#     text = builtins.toJSON (import ./managed_service_accounts.nix);
#    };
  };
}
