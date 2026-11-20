{ unstable, pkgs, ... }:

let
  # Hookscript van tmux-agent-wizard (zelfde als `taw integration install claude`
  # schrijft). Declaratief, want settings.json is een home-manager-symlink en dus
  # read-only voor de installer.
  tawHook = (pkgs.callPackage ../../../pkgs/tmux-agent-wizard { }).claudeHook;
in
{

  programs.claude-code = {
    enable = true;
    package = unstable.claude-code;
    commands = import ./_cc-commands.nix;

    skills = {
      srt-translate-nl = ./skills/srt-translate-nl;
      vikunja-afspraak = ./skills/vikunja-afspraak;
    };

    context = ./global-rules.md;

    settings = {
      includeCoAuthoredBy = false;

      alwaysThinkingEnabled = true;
      promptSuggestionEnabled = false;
      spinnerTipsEnabled = false;
      awaySummaryEnabled = false;
      editorMode = "normal";
      skipAutoPermissionPrompt = true;

      permissions.allow = (import ./_cc-permissions.nix) ++ [ "Bash(*)" ];

      # Moderne rtk (>=0.41) heeft de hook ingebouwd: `rtk hook claude` leest
      # de PreToolUse-JSON van stdin en schrijft de rewrite terug. Het oude
      # gegenereerde ~/.claude/hooks/rtk-rewrite.sh bestaat niet meer (rtk init
      # maakt het niet langer aan), dus verwijzen we direct naar de binary.
      hooks.PreToolUse = [
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = "rtk hook claude";
            }
          ];
        }
      ];

      # tmux-agent-wizard: deze hook meldt in welke Claude-sessie de pane zit, zodat
      # taw het gesprek kan hervatten na een reboot en API-fouten als `error` toont.
      # Matchers zijn die van taw zelf (SessionStart-bronnen, StopFailure-kinds).
      hooks.SessionStart = [
        {
          matcher = "^(startup|resume|clear|compact|fork)$";
          hooks = [
            {
              type = "command";
              command = "bash ${tawHook}/taw-agent-state.sh session";
              timeout = 10;
            }
          ];
        }
      ];

      hooks.StopFailure = [
        {
          matcher = "^(rate_limit|overloaded|authentication_failed|oauth_org_not_allowed|account_on_hold|verification_required|billing_error|invalid_request|model_not_found|server_error|cloud_credential_error|unknown)$";
          hooks = [
            {
              type = "command";
              command = "bash ${tawHook}/taw-agent-state.sh failure";
              timeout = 10;
            }
          ];
        }
      ];

      extraKnownMarketplaces.context-mode.source = {
        source = "github";
        repo = "mksglu/claude-context-mode";
      };

      # i-have-adhd: action-first, ADHD-vriendelijke output-shaping.
      # Marketplace + plugin: https://github.com/ayghri/i-have-adhd
      # Claude Code kan settings.json niet zelf schrijven (home-manager symlink,
      # read-only nix-store), dus de plugin wordt hier declaratief aangezet i.p.v.
      # via `claude plugin install`. Optioneel altijd-aan: `touch ~/.claude/.i-have-adhd-always`.
      extraKnownMarketplaces.i-have-adhd.source = {
        source = "github";
        repo = "ayghri/i-have-adhd";
      };
      enabledPlugins."i-have-adhd@i-have-adhd" = true;

      statusLine = {
        command = "input=$(cat); echo \"[$(echo \"$input\" | jq -r '.model.display_name')] 📁 $(basename \"$(echo \"$input\" | jq -r '.workspace.current_dir')\")\"";
        padding = 0;
        type = "command";
      };
    };
  };

  # Context-docs die de globale CLAUDE.md on-demand inleest (zie de "Context on-demand"-
  # pointers in de context-string hierboven). Bewust buiten die string gehouden zodat ze
  # NIET elke sessie meeladen; Claude leest ze alleen wanneer het onderwerp speelt.
  home.file.".claude/docs/openspec-workflow.md".source = ./claude-context/openspec-workflow.md;
  home.file.".claude/docs/rtk.md".source = ./claude-context/rtk.md;
  home.file.".claude/docs/egh-stijl.md".source = ./claude-context/egh-stijl.md;
}
