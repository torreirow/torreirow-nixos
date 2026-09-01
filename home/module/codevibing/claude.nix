{ unstable, ... }:

{

  programs.claude-code = {
    enable = true;
    package = unstable.claude-code;
    commands = import ./_cc-commands.nix;

    skills = {
      srt-translate-nl = ./skills/srt-translate-nl;
    };

    context = ''
      # Git - Commits
      - Never add self-promoting trailers to commit messages. Do NOT include `Co-authored-by: Claude`, `Co-Authored-By: Claude`, `Generated with Claude Code`, or any similar attribution to Claude/Anthropic. Commits are authored by me alone.

      # Markdown - Styleguide
      - When creating a markdown table which is not wider than 90 chars, use space padding to visually align table borders.

      # Shell scripts - Portability
      - Always use `#!/usr/bin/env` she-bangs (`#!/usr/bin/env bash`, `#!/usr/bin/env python3`, `#!/usr/bin/env zsh`). Never hardcode interpreter paths like `/bin/bash` or `/usr/bin/python3`.

      # Terraform - TechNative
      - In TechNative repositories, always run terraform with `AWS_PROFILE=technative`, e.g. `AWS_PROFILE=technative terraform plan`. Does not apply to other clients' infrastructure — check which account a repository targets before assuming.

      # OpenSpec - Archiving
      - Always archive in small, discrete steps. Large agent operations that try to do everything at once run out of memory (OOM).
      - Required order:
        1. Sync delta specs first (if any exist)
        2. Create the archive directory structure
        3. Move the change directory into the archive
      - Use individual bash commands or small focused operations — never one sweeping agent call.

      # OpenSpec - CHANGELOG
      - After an `/opsx:apply` completes (all tasks done), immediately update the CHANGELOG, before archiving the change.
      - Add entries under `## NEXT VERSION` (create the section if it is missing). `release.sh` replaces that heading with the actual version and date.
      - Use Keep a Changelog format with `### Added`, `### Changed`, `### Fixed` sections.
      - Describe features from the change's `design.md` and `proposal.md`, user-focused, with the feature name in bold:

        ```markdown
        ## NEXT VERSION

        ### Added
        - **Feature name**: Brief description
          - Sub-bullet with details
        ```

      # RTK - Rust Token Killer

      **Usage**: Token-optimized CLI proxy (60-90% savings on dev operations)

      ## Meta Commands (always use rtk directly)

      ```bash
      rtk gain              # Show token savings analytics
      rtk gain --history    # Show command usage history with savings
      rtk discover          # Analyze Claude Code history for missed opportunities
      rtk proxy <cmd>       # Execute raw command without filtering (for debugging)
      ```

      ## Installation Verification

      ```bash
      rtk --version         # Should show: rtk X.Y.Z
      rtk gain              # Should work (not "command not found")
      which rtk             # Verify correct binary
      ```

      ⚠️ **Name collision**: If `rtk gain` fails, you may have reachingforthejack/rtk (Rust Type Kit) installed instead.

      ## Hook-Based Usage

      All other commands are automatically rewritten by the Claude Code hook.
      Example: `git status` → `rtk git status` (transparent, 0 tokens overhead)
    '';

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

      extraKnownMarketplaces.context-mode.source = {
        source = "github";
        repo = "mksglu/claude-context-mode";
      };

      statusLine = {
        command = "input=$(cat); echo \"[$(echo \"$input\" | jq -r '.model.display_name')] 📁 $(basename \"$(echo \"$input\" | jq -r '.workspace.current_dir')\")\"";
        padding = 0;
        type = "command";
      };
    };
  };
}
