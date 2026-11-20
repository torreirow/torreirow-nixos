# tmux-agent-wizard (taw): leest elke tmux-pane en toont per agent de status
# (blocked/error/working/done/idle) in één popup. Twee delen:
#   - taw      : de Rust-binary uit de GitHub-release (musl, statisch)
#   - plugin   : de TPM-plugin (tmux-agent-wizard.tmux + docs) uit dezelfde tag
#   - claudeHook: het hookscript dat `taw integration install claude` zou
#                 neerzetten, hier declaratief gerenderd (settings.json is een
#                 home-manager-symlink, dus de installer kan er niet in schrijven)
{ lib
, stdenvNoCC
, fetchurl
, fetchFromGitHub
, runCommand
, tmuxPlugins
}:

let
  version = "0.1.7";

  src = fetchFromGitHub {
    owner = "27medkamal";
    repo = "tmux-agent-wizard";
    rev = "v${version}";
    hash = "sha256-Fu4Jfw4fFOedK2uWwk2EBE8/TI4RY/jpXFUiRSqAcoI=";
  };

  system = stdenvNoCC.hostPlatform.system;

  tawSrc =
    if system == "x86_64-linux" then
      fetchurl {
        url = "https://github.com/27medkamal/tmux-agent-wizard/releases/download/v${version}/taw-x86_64-unknown-linux-musl.tar.gz";
        hash = "sha256-7MOd3yY9mzQDgZ4o06c51XriEiswZs1jZ93H+1/ojSA=";
      }
    else
      throw "tmux-agent-wizard: geen release-binary voor ${system} (alleen x86_64-linux)";

  taw = stdenvNoCC.mkDerivation {
    pname = "taw";
    inherit version;
    src = tawSrc;
    sourceRoot = ".";
    installPhase = ''
      install -Dm755 taw $out/bin/taw
    '';
    meta = {
      description = "Every agent in your tmux, in one list, with its state";
      homepage = "https://github.com/27medkamal/tmux-agent-wizard";
      license = lib.licenses.mit;
      platforms = [ "x86_64-linux" ];
      mainProgram = "taw";
    };
  };
in
{
  inherit taw;

  plugin = tmuxPlugins.mkTmuxPlugin {
    pluginName = "tmux-agent-wizard";
    inherit version src;
    rtpFilePath = "tmux-agent-wizard.tmux";
    meta = {
      description = "tmux-agent-wizard: every coding agent in your tmux, one key";
      homepage = "https://github.com/27medkamal/tmux-agent-wizard";
      license = lib.licenses.mit;
    };
  };

  # Zelfde script als de installer schrijft, met het store-pad van taw erin.
  # Verwacht python3 in de PATH van de hook (voor de JSON van stdin).
  claudeHook = runCommand "taw-agent-state-claude" { } ''
    install -Dm755 ${src}/src/integration/templates/taw-agent-state-claude.sh $out/taw-agent-state.sh
    substituteInPlace $out/taw-agent-state.sh \
      --replace-fail '{{TAW_BIN}}' '${taw}/bin/taw' \
      --replace-fail '{{AGENT}}' 'claude'
  '';
}
