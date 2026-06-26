self: super: {
  wayle = super.wayle.overrideAttrs (old: {
    src = /home/wtoorren/data/git/torreirow/wayle;
    cargoDeps = super.rustPlatform.fetchCargoVendor {
      inherit (old) pname version;
      src = /home/wtoorren/data/git/torreirow/wayle;
      hash = "sha256-ZvwScjQ+MgVFmIYCSbOjmjh128FomUaIq3cl4hV2s54=";
    };
  });
}
