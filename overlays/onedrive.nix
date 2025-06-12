self: super: {
  onedrivegui = super.onedrivegui.overrideAttrs (oldAttrs: {
    version = "v2.5.5";
    src = super.fetchFromGitHub {
      owner = "abraunegg";
      repo = "onedrive";
      rev = "v2.5.5";
      sha256 = "sha256-apo9rE0oc2NCkgYYCZlBB5S+HqTmYTlDIxLhKoxKoRE=";  # Je moet de werkelijke hash toevoegen
    };
  });
}
