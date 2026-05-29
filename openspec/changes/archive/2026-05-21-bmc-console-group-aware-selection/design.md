## Context

`bmc console -p` triggers an interactive profile selector via `selectProfileForConsole()` in `cmd/console.go`. This function intentionally bypasses the group-based two-step selector used by `bmc profsel` and instead shows a single flat list of all profiles, with recently-used profiles at the top.

The `profsel` command already has a well-tested group-aware selector (`selectProfileInteractive()` in `cmd/profsel.go`) that uses `awsconfig.Groups()`, `awsconfig.ByGroup()`, `ui.Choose()`, and `ui.ErrBack`. All required building blocks exist and are stable.

## Goals / Non-Goals

**Goals:**
- Replace the flat selector in `selectProfileForConsole()` with a two-step group-aware selector
- Surface recently-used groups at the top of step 1
- Surface recently-used profiles at the top of step 2 (within the selected group)
- Preserve back navigation (Escape in step 2 returns to step 1)
- Keep history tracking: selected profile saved to `"console"` history namespace

**Non-Goals:**
- Changing the `-p <name>` (non-interactive) code path
- Modifying `profsel` or any other command
- Adding fuzzy search or filtering
- Changing the history storage format

## Decisions

### Decision: Derive recent groups from profile history, not a separate group history

**Chosen**: Extract the group of each recently-used profile name from the loaded `profiles` slice. Sort groups by how recently any of their profiles was used.

**Alternative considered**: Maintain a separate group-level history file. Rejected — adds complexity and a new file for no extra value. Profile history already encodes which groups were used recently.

**Rationale**: Zero new storage, no migration needed, derives naturally from existing data.

---

### Decision: Keep `selectProfileForConsole()` as a separate function rather than calling `selectProfileInteractive()`

**Chosen**: New private function `selectProfileForConsoleInteractive()` in `console.go` that mirrors the structure of `selectProfileInteractive()` but adds recent-first ordering for both groups and profiles.

**Alternative considered**: Call `selectProfileInteractive()` directly from `profsel.go`. Rejected — that function has no recent-ordering logic and is not exported; changing it would affect `profsel` behaviour.

**Rationale**: Keeps each command's UX concerns self-contained. The new function is ~40 lines and shares all helpers.

---

### Decision: "Recent" groups section header only shown when at least one recent group exists

If the user has no console history, the selector falls back to a plain alphabetically-sorted group list — identical to `profsel` behaviour. No "recent" section header is shown in that case.

## Risks / Trade-offs

- **Risk**: Recent group ordering logic could diverge from profile ordering if history entries reference profiles that no longer exist in `~/.aws/config`.
  → **Mitigation**: Skip missing profiles when building the recent set; fall back gracefully to full list.

- **Trade-off**: Two-step flow is one extra keypress for users who previously used the flat list and knew their profile name. Acceptable because the flat list is already unusable at scale.

## Migration Plan

- Pure code change in `cmd/console.go`, no config or data migration needed.
- Existing `"console"` history file continues to work; profiles saved there are used to derive recent group ordering.
- No flag or CLI interface changes; downstream scripts using `bmc console -p <name>` (non-interactive) are unaffected.

## Open Questions

- None. All required UI primitives and data helpers are confirmed to exist in the current codebase.
