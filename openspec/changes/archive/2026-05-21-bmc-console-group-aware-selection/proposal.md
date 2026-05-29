## Why

`bmc console -p` (interactive profile selection) presents all AWS profiles in a single flat list, making it unusable when many profiles exist. The `bmc profsel` command already solves this with a two-step group-based selector, but `console` has its own selector that deliberately bypasses it.

## What Changes

- Replace `selectProfileForConsole()` in `cmd/console.go` with a group-aware two-step selector
- Step 1: show all groups, with recently-used groups surfaced at the top
- Step 2: show profiles within the selected group, with recently-used profiles at the top
- Back navigation (pressing Escape/back in step 2 returns to step 1) — reuses existing `ui.ErrBack` mechanism already present in `profsel`
- History tracking remains: after a successful interactive selection, the chosen profile is saved to history (existing behaviour preserved)

## Capabilities

### New Capabilities

- `console-group-selector`: Two-step group-aware interactive profile selector for `bmc console -p`, with recent-first ordering at both the group and profile level

### Modified Capabilities

<!-- none -->

## Impact

- **File changed**: `cmd/console.go` — `selectProfileForConsole()` replaced
- **No new dependencies**: reuses `awsconfig.Groups()`, `awsconfig.ByGroup()`, `ui.Choose()`, `ui.ErrBack`, and `history.Load()` already used in `profsel`
- **No API/flag changes**: `-p` flag behaviour is unchanged from the user's perspective
- **Existing history file** (`console` namespace) is reused; recent profiles are now also used to rank groups
