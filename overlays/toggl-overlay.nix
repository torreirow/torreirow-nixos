self: super:


{
  toggl-cli = super.toggl-cli.overrideAttrs (old: rec {
    version = "v3.0.1";
    name = "toggl-cli-${version}";
    src = super.requireFile {
      name = "${version}.tar.gz";
      sha256 = "12yac8b897rnnjrp2jmriqvjcsx2ckjfps5nxhwjxc30svac222h";
      message = ''
      This nix expression requires that ${name} is already part of the store.
      Download it from https://sidefx.com and add it to the nix store with:
          nix-prefetch-url <URL>
      This can't be done automatically because you need to create an account on
      their website and agree to their license terms before you can download
      it. That's what you get for using proprietary software.
      '';

    };
  });
}