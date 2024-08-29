final: prev: {                                                                                                                                                                                                    
                                                                                                                                                                                                                  
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
        hash = "sha256-IGbd7Zgx1ovhHVheHJ1GXEYlhKxgpVRVmVpN2Xjn6mU="; # Vervang met de juiste SHA256-hash
      };
    });
  };

  jsonify-aws-dotfiles = prev.buildGoModule rec {
        pname = "jsonify-aws-dotfiles";
        version = "2.1.0";
        src = prev.fetchFromGitHub {
          owner = "niko-dunixi";
          repo = "jsonify-aws-dotfiles";
          #rev = "v${version}";
          sha256 = "sha256-CojP1a19b2zKfUMp+wN7FFs+SzSoc8sYqKvXTg4RnOA=";
        };
        #vendorHash = "sha256-KO8cbkqdAkGkNrqBh3wIWaQyvf9hqrKjXWbElpQzMpg=";
      };

}    
