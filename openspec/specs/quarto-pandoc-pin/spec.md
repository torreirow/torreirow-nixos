# quarto-pandoc-pin Specification

## Purpose
Quarto op malandro en lobos rendert presentaties zonder pandoc-fouten, doordat quarto een eigen, compatibele pandoc-versie gebruikt terwijl de systeem-pandoc ongewijzigd blijft.

## Requirements

### Requirement: Quarto gebruikt een eigen, compatibele pandoc
Quarto (1.9.38) op malandro en lobos SHALL een eigen pandoc 3.8.3 gebruiken in plaats van de
systeem-pandoc, omdat de pandoc uit nixpkgs niet samenwerkt met deze quarto-versie
(`Unknown option "syntax-highlighting"`).

#### Scenario: RevealJS-presentatie rendert zonder fout
- **WHEN** quarto op malandro een `.qmd`-bestand met RevealJS-formaat rendert
- **THEN** geeft pandoc geen `Unknown option "syntax-highlighting"` en wordt de presentatie gemaakt

#### Scenario: R- en Python-pakketten blijven beschikbaar
- **WHEN** quarto op malandro wordt aangeroepen
- **THEN** zijn het R-pakket `reticulate` en de Python-pakketten plotly, numpy, pandas, matplotlib
  en tabulate beschikbaar in de quarto-omgeving

### Requirement: Systeem-pandoc blijft ongemoeid
De systeem-pandoc SHALL de versie uit nixpkgs blijven; alleen quarto SHALL de eigen pandoc
gebruiken.

#### Scenario: Systeem-pandoc ongewijzigd
- **WHEN** `pandoc --version` op malandro wordt uitgevoerd
- **THEN** toont de uitvoer de nixpkgs-versie (nu 3.7.0.2), niet 3.8.3
