self: super:
    {
      toggl-cli = super.toggl-cli.overrideAttrs (oldAttrs: rec {
      src = super.fetchFromGitHub {
      owner = "AuHau";
      repo = "toggl-cli";
      rev = "v2.4.4";
      sha256 = "1iag18r77xvcgway67qx0xnn3gf367c104w2rr71m9fc9zc67cm5";
         };
      });
    }


  nixpkgs.overlays = [
    (self: super:
    {
      redshift = super.redshift.overrideAttrs (oldAttrs: rec {
        src = super.fetchFromGithub {
          owner = "minus7";
          repo = "redshift";
          rev = "eecbfedac48f827e96ad5e151de8f41f6cd3af66";
          sha256 = "0rs9bxxrw4wscf4a8yl776a8g880m5gcm75q06yx2cn3lw2b7v22";
        };
      });
    })
  ];
