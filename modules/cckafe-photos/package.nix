{ writeShellApplication, curl, coreutils, gnugrep, python3 }:

writeShellApplication {
  name = "cckafe-photos";
  runtimeInputs = [ curl coreutils gnugrep python3 ];
  text = builtins.readFile ./fetch.sh;
}
