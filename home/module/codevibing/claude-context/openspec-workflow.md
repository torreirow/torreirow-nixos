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
