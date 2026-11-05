{ writeShellApplication, curl, coreutils, gnugrep }:

writeShellApplication {
  name = "immich-ml-catchup";
  runtimeInputs = [ curl coreutils gnugrep ];
  text = builtins.readFile ./catchup.sh;
}
