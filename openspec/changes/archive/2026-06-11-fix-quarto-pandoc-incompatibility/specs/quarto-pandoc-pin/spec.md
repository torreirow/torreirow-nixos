## ADDED Requirements

### Requirement: Quarto on malandro uses pandoc 3.6
Quarto on malandro SHALL use pandoc 3.6 (from nixpkgs-2505) instead of the system pandoc 3.7.0.2, so that the `syntax-highlighting` writer option is accepted.

#### Scenario: RevealJS presentation renders without error
- **WHEN** quarto renders a `.qmd` file with RevealJS format on malandro
- **THEN** pandoc does not produce `Unknown option "syntax-highlighting"` and the presentation renders successfully

#### Scenario: R and Python packages remain available
- **WHEN** quarto is invoked on malandro
- **THEN** the `reticulate` R package and Python packages (plotly, numpy, pandas, matplotlib, tabulate) are available in the quarto environment

### Requirement: System pandoc is unaffected
The system pandoc package on malandro SHALL remain at 3.7.0.2; only quarto's internal pandoc reference SHALL be pinned to 3.6.

#### Scenario: System pandoc version unchanged
- **WHEN** `pandoc --version` is run on malandro
- **THEN** the output shows pandoc 3.7.0.2 (not 3.6)
