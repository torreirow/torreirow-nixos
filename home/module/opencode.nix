{ unstable, pkgs, lib, ... }: {
    programs.opencode = {
      enable = true;
      # opencode-mem gebruikt onnxruntime-node; dat heeft libstdc++ nodig in LD_LIBRARY_PATH
      package = pkgs.symlinkJoin {
        name = "opencode-with-libstdc++";
        paths = [ unstable.opencode ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/opencode \
            --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}
        '';
      };
      agents = { };
      context = ./codevibing/global-rules.md;
      commands = (import ./codevibing/_cc-commands.nix) // {
        i-have-adhd = ./codevibing/i-have-adhd-command.md;
      };
      settings = {
        share = "manual";
        update = "notify";
        permissions = [
          { action = "read"; resource = "*.env"; effect = "allow"; }
          { action = "read"; resource = "*.env.*"; effect = "allow"; }
        ];
        plugins = [
          "@tarquinen/opencode-dcp@latest"
          "opencode-snip@latest"
          "opencode-mem@latest"
        ];
        providers = {
          anthropic = {
            settings = {
              baseURL = "https://api.anthropic.com/v1";
            };
          };
        };
        compaction = {
          auto = true;
          keep = { tokens = 15000; };
          buffer = 16000;
        };
      };
      themes = { };
    };
    # V2 leest TUI-instellingen uit cli.json (home-manager genereert alleen V1 tui.json)
    xdg.configFile."opencode/cli.json" = {
      force = true;
      text = ''
        {
          "$schema": "https://opencode.ai/v2/cli.json",
          "theme": {
            "name": "opencode"
          }
        }
      '';
    };
    xdg.configFile."opencode/opencode-mem.jsonc".text = ''
      {
        "opencodeProvider": "opencode-go",
        "opencodeModel": "inherit"
      }
    '';
    xdg.configFile."opencode/dcp.jsonc".text = ''
      {
        "$schema": "https://raw.githubusercontent.com/Opencode-DCP/opencode-dynamic-context-pruning/master/dcp.schema.json",
        "compress": {
          "minContextLimit": "40%",
          "maxContextLimit": "75%",
          "permission": "allow"
        },
        "strategies": {
          "deduplication": { "enabled": true },
          "purgeErrors": { "enabled": true, "turns": 4 }
        }
      }
    '';
    xdg.configFile."opencode/skills/i-have-adhd/SKILL.md".source = ./codevibing/skills/i-have-adhd/SKILL.md;
    xdg.configFile."opencode/plugins/rtk.js".source = ./codevibing/opencode-rtk-plugin.js;
}
