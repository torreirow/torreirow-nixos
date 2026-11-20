{ writeShellApplication, curl, coreutils, gnugrep, python3, imagemagick }:

writeShellApplication {
  name = "cckafe-photos";
  runtimeInputs = [ curl coreutils gnugrep python3 imagemagick ];
  text = builtins.readFile ./fetch.sh;
}
