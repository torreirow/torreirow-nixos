{

  "wto:1shotpoc" = ''
          ---
          description: creates a new project based on the existing context my way
          ---
          Can you create a set of artifacts I can use to let claude code
          autonomously build the PoC which could serve as an alpha base for
          later development.

          We will use beans as internal ticket system for milestones and epics.
          Run `beans init` to setup and `beans prime` to undestand how it
          works. Claude Code should administer the milestones and epics.
          Milestone title should start with an incremental two digit
          number:starting with `01`

          We will use OpenSpec for creating proposals and keeping track of all
          tasks within an epic. OpenSpec needs to be fully setup before the
          project can take off. start with `openspec init.

          We need thourough testing and e2e testcases to prove our PoC is
          working as it should.

          The PoC need to work with nix and nix flakes from the start. Do
          not use flake-utils but plain nix to setup supported architectures.

          We will use jj for version control. Wouter will give you the url of the
          remote repository. You should commit after every archival of a
          openspec change. Commit as Wouter van der Toorren, no self promotion.
  '';

  "wto:ship" = ''
    ---
    description: Ship one OpenSpec change end-to-end (apply → gate → archive → commit → push → close bean)
    ---

    Ship the OpenSpec change named in the arguments as a single gated step. One
    change per invocation. Argument: the change name (kebab-case). If omitted, run
    `openspec list` and use the sole active change, or ask which one.

    Do this in order; do not skip the gate:

    1. **Announce & open the bean.** State the change. Find the linked bean (look for
       an "OpenSpec change" note referencing it, or `beans list -S "<change>"`) and
       mark it in-progress: `beans update <id> -s in-progress`. If no bean exists,
       continue without one.

    2. **Implement.** Invoke the openspec-apply-change skill for this change.
       Implement every task with thorough tests and check each off in `tasks.md`
       (`- [ ]` → `- [x]`). Do not stop until all tasks are complete. If genuinely
       blocked, stop and report — do not ship a partial change.

    3. **Update the CHANGELOG.** Add a concise, user-facing bullet to the
       `## [Unreleased]` section of `CHANGELOG.md`, under the right category —
       `### Added` (new capability), `### Changed` (behavior/rename), `### Fixed`
       (bug). Create the category subsection if it's missing. Keep it one or two
       lines describing the change from a user's perspective (not the commit hash).
       `release.sh` promotes this section to a version at release time. (Pure-internal
       refactors with no user-visible effect may skip this — note that you did.)

    4. **Ship (gated).** Run:
       `bash scripts/ship-change.sh <change> "<commit subject>"`
       This stages the tree (including the CHANGELOG edit), runs the gate
       (`nix flake check` — build + tests + coverage ≥70% overall / ≥80% core),
       archives the change, commits as Wouter van der Toorren with no self-promotion, and pushes
       `main`. Write a clear one-line commit subject describing the change. If the
       gate fails, fix the code and re-run — never bypass it.

    5. **Close the bean.** Mark the linked bean(s) completed with a
       `## Summary of Changes` section. If the bean is an epic whose parent
       milestone now has all epics completed, mark the milestone completed too.

    6. **Report.** Change archived name, commit id, coverage summary, bean(s) closed.

    Rules: never skip the gate; commit as Wouter van der Toorren, no self-promotion; keep changes
  '';

  "wto:flaker" = ''
          ---
          description: creates a flake.nix for the current project
          ---
          check which programming langauge is used for this project and use the
          instructions from https://github.com/wtowto/agent-do-it-my-way for
          make a flake for this project-type. If the language is not listed
          create a flake in the spirit of add-flake-to-nodejs-project.md.
  '';

  "wto:translate" = ''
          ---
          argument-hint: [message]
          description: translates between Dutch and English
          ---
          Translate the following between Dutch and English. Auto-detect
          the source language. Keep the tone and register of the original.

          the following can be
            - a text fragment -> translate in this session
            - a file path -> translate the complete file overwriting the existing text
            - a file path with range -> translate the text withing the range overwriting the existing text

          $ARGUMENTS
  '';
  "cas:1shotepic" = ''
  ---
  description: autonomously implements an existing Beans epic
  ---
  You are working in an existing project.

  The user provides a Bean ID as the argument:

    /cas:1shotepic <project>-<number>

  Example:

    /cas:1shotepic elastinix-wxy7

  The complete argument is the Bean ID and must be used verbatim.

  The part before the final "-" identifies the project.

  ## 1. Understand the project

  First inspect the current project and repository state.

  Run:

    beans prime

  Use the instructions provided by `beans prime` as the authoritative
  documentation for working with Beans.

  Inspect the current JJ repository state before making any changes.

  Do not discard, overwrite or modify unrelated existing work.

  Do not reinitialize Beans, OpenSpec, Nix, Git or JJ when they are
  already configured.

  ## 2. Identify and understand the epic

  The provided argument is the Bean ID of the epic to implement.

  Inspect the Bean using the appropriate Beans commands.

  Example:

    beans show <bean-id>

  Verify that the specified Bean is an epic.

  Do not create a new epic.

  Before implementing anything, understand:

  - the complete epic description;
  - its acceptance criteria;
  - child Beans/tasks;
  - dependencies;
  - related Beans;
  - existing implementation;
  - relevant project documentation;
  - relevant OpenSpec specifications;
  - existing tests.

  Treat the specified epic as the unit of work.

  ## 3. OpenSpec

  Use the existing OpenSpec configuration and workflow.

  Do not run `openspec init` if OpenSpec is already configured.

  Before creating a new OpenSpec change, inspect the existing OpenSpec
  structure and relevant specifications.

  Use OpenSpec proposals/changes for work that requires specification
  changes according to the existing project workflow.

  For every OpenSpec change:

  1. Create the proposal/change.
  2. Implement the change.
  3. Add or update the relevant tests.
  4. Verify the implementation.
  5. Archive the OpenSpec change when it is completely implemented.
  6. Commit the archived change using JJ.

  ## 4. Implementation

  Work autonomously through the entire epic.

  If the epic already contains child Beans/tasks, use those as the
  implementation plan.

  If additional tasks are required to correctly implement the epic,
  create the necessary child Beans/tasks rather than hiding the work
  inside another task.

  Keep Beans up to date throughout the implementation.

  Do not modify unrelated Beans or unrelated project work.

  If the epic is partially implemented, inspect the current state and
  continue from where the previous work stopped.

  Do not start over unnecessarily.

  ## 5. Testing

  Thorough testing is required.

  Add or update tests as appropriate, including:

  - unit tests;
  - integration tests;
  - E2E tests.

  Run all relevant:

  - tests;
  - linters;
  - formatters;
  - type checks;
  - build checks;
  - Nix checks.

  Fix failures before continuing.

  Do not consider the epic complete merely because the code compiles.

  The acceptance criteria of the epic must be demonstrably satisfied.

  ## 6. Nix

  Respect the existing Nix/NixOS and flake configuration.

  If the project uses Nix flakes, keep the implementation compatible
  with the existing supported architectures.

  Do not introduce `flake-utils` unless the existing project already
  explicitly depends on it.

  Prefer plain Nix for architecture handling.

  Do not unnecessarily restructure or replace the existing Nix setup.

  ## 7. JJ / version control

  JJ is the version-control system for this project.

  Do NOT create a Git branch for the epic unless explicitly requested
  by the user.

  Use JJ changes and commits to maintain the development history.

  Before making changes, inspect the current JJ working-copy state.

  Never discard unrelated existing changes.

  After every OpenSpec archival:

  1. Review the resulting changes.
  2. Verify the tests relevant to that change.
  3. Create a JJ commit.

  Commit as:

    Wouter van der Toorren

  Do not add self-promotional text, attribution or generated-by
  messages to commits.

  Keep the JJ history clean and understandable.

  ## 8. Autonomy

  Work autonomously.

  Do not ask for confirmation between individual tasks.

  Make reasonable technical decisions based on:

  - the epic;
  - child Beans;
  - the existing codebase;
  - existing architecture;
  - project conventions;
  - OpenSpec specifications;
  - tests;
  - documentation.

  Only ask the user a question when you encounter a genuinely blocking
  decision that cannot reasonably be resolved from the available
  information.

  ## 9. Completion

  Continue until the epic is actually complete.

  The epic can only be considered complete when:

  - all required implementation is complete;
  - all acceptance criteria are satisfied;
  - all relevant child Beans/tasks are complete;
  - tests and verification pass;
  - OpenSpec changes are archived;
  - Beans accurately reflects the final state;
  - every OpenSpec archival has been committed with JJ;
  - no unrelated work has been modified.

  At the end, provide a concise summary containing:

  - what was implemented;
  - which Beans/tasks were completed;
  - which additional Beans/tasks were created, if any;
  - which OpenSpec changes were created and archived;
  - which JJ commits were created;
  - which tests/checks were executed;
  - any remaining blockers or follow-up work.
'';
}
