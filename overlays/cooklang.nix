self: super: {
  cooklang = super.rustPlatform.buildRustPackage rec {
    pname = "cooklang";
    version = "unstable-2025-10-04";

    src = super.fetchFromGitHub {
      owner = "cooklang";
      repo = "CookCLI";
      rev = "master";
      sha256 = "sha256-h29X2/4L4HxSQTGroBP9ODQYadRUuFGip6yTxdhOQLg=";
    };

    cargoLock = {
      lockFile = src + "/Cargo.lock";
    };

    # Belangrijk voor openssl-sys
    nativeBuildInputs = [ super.pkg-config ];
    buildInputs = [ super.openssl super.perl ];

    meta = with super.lib; {
      description = "CookLang CLI (Rust-only build)";
      homepage = "https://github.com/cooklang/CookCLI";
      license = licenses.mit;
      platforms = platforms.unix;
    };
  };
}

