{ pkgs, ... }:

let
  # Definieer de bron van de specifieke versie van toggl-cli
  toggl-cli-src = pkgs.fetchFromGitHub {
    owner = "AuHau";
    repo = "toggl-cli";
    rev = "v2.4.4";
    sha256 = "1iag18r77xvcgway67qx0xnn3gf367c104w2rr71m9fc9zc67cm5"; # Zorg ervoor dat deze waarde correct is
  };

  # Gebruik Python 3.12 en bouw het pakket
#  python312 = pkgs.python312;
#  toggl-cli = python312.pkgs.buildPythonPackage {
#    pname = "toggl-cli";
#    version = "2.4.4";
#    src = toggl-cli-src;
#    propagatedBuildInputs = [
#      pkgs.python312Packages.requests
#      pkgs.python312Packages.click
#      pkgs.python312Packages.setuptools
#      pkgs.python312Packages.wheel
#      pkgs.python312Packages.twine
#    ];
#    meta = {
#      description = "Toggl command line interface";
#      homepage = "https://github.com/AuHau/toggl-cli";
#      license = pkgs.lib.licenses.mit;
#    };
#  };
in
{
  # Voeg Python 3.12 en toggl-cli toe aan de systeem pakketten
  environment.systemPackages = with pkgs; [
#    python312
    toggl-cli
  ];
}


