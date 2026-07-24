{ lib, buildGoModule }:

buildGoModule {
  pname = "formrelay";
  version = "0.1.0";

  src = ./.;

  vendorHash = null;

  meta = {
    description = "Self-hosted form-to-email relay with hCaptcha support";
    mainProgram = "formrelay";
    license = lib.licenses.mit;
  };
}
