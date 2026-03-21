final: prev:

{
  ssmsh = prev.buildGoModule rec {
    pname = "ssmsh";
    version = "1.5.0";

    src = prev.fetchFromGitHub {
      owner = "torreirow";
      repo = "ssmsh";
      rev = "v${version}";
      hash = "sha256-sT9NUpleaAbWQIge5+cKdJkW/fNQJJ1aPSuwW3x8aqk=";
    };

    vendorHash = "sha256-+7duWRe/haBOZbe18sr2qwg419ieEZwYDb0L3IPLA4A=";

    meta = with prev.lib; {
      description = "A shell for AWS Systems Manager Parameter Store";
      homepage = "https://github.com/torreirow/ssmsh";
      license = licenses.mit;
      maintainers = [ ];
    };
  };
}
