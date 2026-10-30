{ lib, buildGoModule }:

buildGoModule {
  pname = "filedrop";
  version = "0.1.0";

  src = ./.;

  vendorHash = null;

  meta = {
    description = "Upload-only form (Cap CAPTCHA) that streams files into a Nextcloud File Drop share";
    mainProgram = "filedrop";
    license = lib.licenses.mit;
  };
}
