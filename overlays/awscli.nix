self: super: {
  awscli2 = super.awscli2.overrideAttrs (oldAttrs: {
    version = "2.18.16";
    src = super.fetchFromGitHub {
      owner = "aws";
      repo = "aws-cli";
      rev = "2.18.16";
      sha256 = "sha256-apo9rE0oc2NCkgYYCZlBB5S+HqTmYTlDIxLhKoxKoRE=";  # Je moet de werkelijke hash toevoegen
    };
  });
}
