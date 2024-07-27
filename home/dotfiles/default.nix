{
  # Technative AWS Accounts JSON/NIX file

  home.file = {
    ".ohmyzsh-wouter" = {
      source = ./.ohmyzsh-wouter;
      recursive = true;
    };
    ".config" = {
      source = ./.config;
      recursive = true;
    };
#    ".aws/managed_service_accounts.json" = {
#     text = builtins.toJSON (import ./managed_service_accounts.nix);
#    };
  };
}
