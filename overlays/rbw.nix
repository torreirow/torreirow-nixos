self: super:

{
  rbw = super.rbw.overrideAttrs (old: rec {
    version = "1.15.0";

    src = super.fetchFromGitHub {
      owner = "doy";
      repo = "rbw";
      rev = "v${version}";
      sha256 = "sha256:d8174b0aeaccbcd80322ca41fb48bf2dbad8fc4d5d9c509c42bbb46d5e195395";
    };

    cargoHash = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
  });
}
