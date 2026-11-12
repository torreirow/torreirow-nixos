# Eigen wayle-fork. `src` is de flake-input wayle-src (gepind in flake.lock), niet de
# lokale checkout: een pad zou ook target/ en .git meenemen, waardoor elke cargo- of
# git-actie in de fork een volledige rebuild bij `home-manager switch` gaf.
# Nieuwe fork-versie: pushen, dan `nix flake update wayle-src`; wijzigt Cargo.lock,
# dan ook de hash hieronder bijwerken.
src:

self: super: {
  wayle = super.wayle.overrideAttrs (old: {
    inherit src;
    cargoDeps = super.rustPlatform.fetchCargoVendor {
      inherit (old) pname version;
      inherit src;
      hash = "sha256-NlziU9xphdl5c0tYGvoMTB7bM4YpOCjrTYlTGciCpr0=";
    };
  });
}
