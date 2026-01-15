self: super:

{
  rbw = super.rbw.overrideAttrs (old: rec {
    version = "1.15.0";

    src = super.fetchFromGitHub {
      owner = "doy";
      repo = "rbw";
      rev = "${version}";
      hash = "sha256-N/s1flB+s2HwEeLsf7YlJG+5TJgP8Wu7PHNPWmVfpIo=";
    };

    cargoDeps = super.rustPlatform.importCargoLock {
      lockFile = "${src}/Cargo.lock";
    };
  });
}
