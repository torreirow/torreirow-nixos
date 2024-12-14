final: prev: 

{
  quarto = prev.quarto.override {
    extraPythonPackages = ps: with ps; [
      plotly
      numpy
      pandas
      matplotlib
      tabulate
    ];

  };


  python311Packages = prev.python311Packages // {
    toggl-cli = prev.python311Packages.toggl-cli.overrideAttrs (old: rec {
      version = "3.0.2";
      src = prev.fetchPypi {
        pname = "togglCli";
        inherit version;
        hash = "sha256-IGbd7Zgx1ovhHVheHJ1GXEYlhKxgpVRVmVpN2Xjn6mU="; 
      };
    });

  };

  opsgenie-sdk = prev.python311Packages.buildPythonPackage rec {
  pname = "opsgenie-sdk";
  version = "2.1.5";

  src = prev.fetchPypi {
    inherit pname version;
    hash = "sha256-w4ovDHrLy+uSAs7YDshXte2i2ZkZOS/tQIO9+nvjJmk=";
  };

  # Voeg de benodigde build dependencies toe
  nativeBuildInputs = [ prev.python311Packages.setuptools prev.python311Packages.wheel prev.python311Packages.pip ];

  propagatedBuildInputs = with prev.python311Packages; [
    requests
    tenacity
    python-dateutil
    prettytable
  ];

  meta = with prev.lib; {
    description = "Opsgenie SDK for Python";
    license = licenses.mit;
    homepage = "https://github.com/opsgenie/opsgenie-python-sdk";
    maintainers = with maintainers; [ ];
  };
};

}

