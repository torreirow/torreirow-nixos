{ stdenv, fetchFromGitHub, buildGoModule }:

buildGoModule rec {
  pname = "atuin";
  version = "18.3.0";

  src = fetchFromGitHub {
    owner = "atuinsh";
    repo = pname;
    rev = "refs/tags/v${version}";
    sha256 = "18ac8wr45g7nc1b6ipgjakg9hfpc9ihxwqwc7gv9rr03hpa0hxa3"; # Vervang door de juiste SHA256 hash
  };

  vendorSha256 = null;

  meta = with stdenv.lib; {
    description = "Magic shell history";
    homepage = "https://github.com/atuinsh/atuin";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
  };
}
