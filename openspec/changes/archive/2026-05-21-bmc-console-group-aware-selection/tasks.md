## 1. Preparation

- [x] 1.1 Clone / open the bmc repository (`github.com/wearetechnative/bmc`) and confirm the current state of `cmd/console.go` and `cmd/profsel.go`
- [x] 1.2 Verify that `awsconfig.Groups()`, `awsconfig.ByGroup()`, `ui.Choose()`, `ui.ErrBack`, and `history.Load()` are all exported and usable from `cmd/console.go`

## 2. Core Implementation

- [x] 2.1 Add a helper `recentGroups(profiles []awsconfig.Profile, recentProfiles []string) []string` that derives the ordered list of recently-used groups from the console profile history
- [x] 2.2 Replace `selectProfileForConsole()` with `selectProfileForConsoleInteractive()` implementing the two-step group-aware selector:
  - Step 1: show recent groups (if any) followed by all groups
  - Step 2: show recent profiles (if any) followed by all profiles in the selected group
  - Back navigation: on `ui.ErrBack` in step 2, loop back to step 1
  - Exit: on empty selection or error in step 1, return empty profile
- [x] 2.3 Update the call sites in `runConsole()` to use the new function name

## 3. Testing

- [x] 3.1 Manually test with no console history: verify plain group list appears, two-step flow works, profile opens correctly
- [x] 3.2 Manually test with existing console history: verify recent groups appear at top of step 1, recent profiles appear at top of step 2
- [x] 3.3 Test back navigation: Escape on step 2 returns to step 1 without exiting
- [x] 3.4 Test Escape on step 1 exits cleanly
- [x] 3.5 Test `bmc console -p <name>` (non-interactive) still works unchanged
- [x] 3.6 Confirm history is saved after interactive selection

## 4. Cleanup & PR

- [x] 4.1 Remove the old `selectProfileForConsole()` function and any dead imports
- [x] 4.2 Update the inline comment above the function to reflect the new behaviour
- [x] 4.3 Open a pull request against `github.com/wearetechnative/bmc` with a clear description referencing this change
