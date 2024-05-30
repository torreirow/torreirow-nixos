self: super: {
  python311Packages = super.python311Packages // {
    toggl-cli = super.python311Packages.buildPythonPackage rec {
      pname = "toggl-cli";
      version = "2.4.4"; # Specificeer hier de gewenste versie

      src = super.fetchPypi {
        inherit pname version;
        sha256 = "2a96b494e1e80caf9c18b31f371c366a5c1f2912"; # Vervang dit door de werkelijke sha256 hash van deze versie
      };

      propagatedBuildInputs = [ super.python311Packages.requests ];

      meta = with super.lib; {
        description = "Command line interface for Toggl";
        homepage = "https://github.com/AuHau/toggl-cli/";
        license = licenses.mit;
        maintainers = with maintainers; [ ape ];
      };
    };
  };
}

