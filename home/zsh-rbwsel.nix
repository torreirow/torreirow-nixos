# zsh-functie rbwsel: kies het actieve rbw-profiel (gedeeld door home/zsh.nix en het
# wtoorren-admin-profiel). Geeft een string terug die in initContent wordt geplakt.
''
      rbwsel() {
        local config_dir="$HOME/.config"
        local active_file="$config_dir/rbw/active-profile"
        local -a profiles=()

        # Default profiel (lege RBW_PROFILE)
        [[ -d "$config_dir/rbw" ]] && profiles+=("(default)")

        # Benoemde profielen: rbw-<naam> directories
        for dir in "$config_dir"/rbw-*/; do
          [[ -d "$dir" ]] || continue
          local name="''${dir%/}"
          name="''${name##*/rbw-}"
          profiles+=("$name")
        done

        if [[ ''${#profiles[@]} -eq 0 ]]; then
          echo "Geen rbw profielen gevonden in $config_dir" >&2
          return 1
        fi

        local selected
        selected=$(printf '%s\n' "''${profiles[@]}" | gum choose --header "Kies RBW profiel")
        [[ -z "$selected" ]] && return 0

        local profile=""
        [[ "$selected" != "(default)" ]] && profile="$selected"

        echo "$profile" > "$active_file"
        export RBW_PROFILE="$profile"
        tmux setenv RBW_PROFILE "$profile" 2>/dev/null || true
        echo "RBW profiel: ''${profile:-(default)}"

        # `rbw unlocked` geeft exit 0 als de vault al open is
        if rbw unlocked 2>/dev/null; then
          echo "Vault is al unlocked"
          return 0
        fi

        echo "Vault is locked, unlocken..."
        rbw unlock
        if rbw unlocked 2>/dev/null; then
          echo "Vault unlocked"
        else
          echo "Unlock van profiel ''${profile:-(default)} mislukt" >&2
          return 1
        fi
      }''
