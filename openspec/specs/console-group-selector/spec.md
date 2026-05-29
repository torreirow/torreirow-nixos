## ADDED Requirements

### Requirement: Group-aware two-step interactive selector for console
When `bmc console -p` is invoked without a profile name, the system SHALL present a two-step interactive selector: first a list of AWS account groups, then a list of profiles within the selected group.

#### Scenario: User selects a group then a profile
- **WHEN** the user runs `bmc console -p` with no profile name argument
- **THEN** the selector first shows all available groups
- **THEN** after the user selects a group, the selector shows only the profiles belonging to that group
- **THEN** after the user selects a profile, the console opens for that profile

#### Scenario: Back navigation from profile list to group list
- **WHEN** the user is on the profile selection step and presses the back key (Escape)
- **THEN** the selector returns to the group selection step without exiting

#### Scenario: Exit from group selection step
- **WHEN** the user presses Escape on the group selection step
- **THEN** the command exits without opening a console

### Requirement: Recent groups surfaced at top of group list
The group selector SHALL display recently-used groups (derived from console profile history) at the top of the list, above all other groups.

#### Scenario: Recently-used groups shown first
- **WHEN** the user has previously selected profiles via `bmc console -p`
- **THEN** the groups of those profiles appear at the top of the group list, ordered by most recent use
- **THEN** all remaining groups follow in their default order

#### Scenario: No history — plain group list
- **WHEN** the user has no console history
- **THEN** the group list is shown without a "recent" section, in default order

### Requirement: Recent profiles surfaced at top of profile list
Within the profile selection step, the system SHALL display recently-used profiles for the selected group at the top of the list.

#### Scenario: Recently-used profiles shown first within group
- **WHEN** the user selects a group that contains profiles they have used before
- **THEN** those profiles appear at the top of the profile list, ordered by most recent use
- **THEN** all remaining profiles in the group follow in their default order

#### Scenario: No recent profiles in selected group
- **WHEN** the user selects a group for which no profiles exist in console history
- **THEN** the profile list is shown without a "recent" section, in default order

### Requirement: Console history preserved after interactive selection
After a successful interactive profile selection, the system SHALL save the selected profile name to the `"console"` history namespace (existing behaviour preserved).

#### Scenario: Profile saved to history
- **WHEN** the user completes an interactive console session by selecting a profile
- **THEN** the selected profile name is appended to the console history
- **THEN** on the next invocation, that profile's group appears near the top of the group list
