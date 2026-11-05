# Test van modules/immich-vaapi-patch.nix:
#
#   nix build .#checks.x86_64-linux.immich-vaapi-patch -L
{ runCommand, callPackage, nodejs, immich }:

let
  patched = callPackage ./immich-vaapi-patch.nix { inherit immich; };
  dist = p: "${p}/lib/node_modules/immich/dist";
in
runCommand "immich-vaapi-patch-test" { nativeBuildInputs = [ nodejs ]; } ''
  set -euo pipefail
  cd ${dist patched}
  node ${./immich-vaapi-patch_test.mjs} ${dist patched} ${dist immich}
  # De wrapper start de gepatchte kopie, niet het origineel.
  grep -qF "${patched}/lib/node_modules/immich" ${patched}/bin/server
  ! grep -qF "${immich}" ${patched}/bin/server
  echo ok > $out
''
