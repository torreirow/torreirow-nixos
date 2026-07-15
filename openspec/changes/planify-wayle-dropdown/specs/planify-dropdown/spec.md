## ADDED Requirements

### Requirement: Badge toont totaal open taken

De wayle bar-module voor Planify SHALL het totaal aantal open (niet-afgeronde,
niet-verwijderde) taken in het geconfigureerde project tonen als badge-tekst.

#### Scenario: Taken aanwezig

- **WHEN** het geconfigureerde project open taken bevat
- **THEN** toont de badge het exacte aantal als getal (bijv. "10")

#### Scenario: Geen open taken

- **WHEN** het geconfigureerde project geen open taken heeft
- **THEN** toont de badge "0"

#### Scenario: Project niet gevonden

- **WHEN** de geconfigureerde projectnaam niet bestaat in de database
- **THEN** toont de badge "?" en de tooltip "Project niet gevonden"

---

### Requirement: Taken gegroepeerd op urgentie in dropdown

De dropdown SHALL taken tonen in drie secties, in volgorde:
1. **Verlopen** — taken met `due.date < vandaag` (alleen als er zijn)
2. **Vandaag** — taken met `due.date = vandaag` én taken zonder deadline
3. **Komend** — taken met `due.date > vandaag` (alleen als er zijn)

Taken zonder deadline worden altijd in de "Vandaag" sectie geplaatst.

#### Scenario: Verlopen taken aanwezig

- **WHEN** het project taken heeft met een deadline vóór vandaag
- **THEN** verschijnt de sectie "Verlopen" bovenaan met die taken in rode stijl

#### Scenario: Geen verlopen taken

- **WHEN** geen enkel open taken een datum heeft vóór vandaag
- **THEN** wordt de sectie "Verlopen" niet getoond

#### Scenario: Taken zonder deadline

- **WHEN** open taken geen deadline hebben
- **THEN** worden ze getoond in de sectie "Vandaag", onder taken met deadline=vandaag

#### Scenario: Komende taken aanwezig

- **WHEN** het project taken heeft met een deadline na vandaag
- **THEN** verschijnt de sectie "Komend" onderaan met datum weergegeven per taak

---

### Requirement: Planify openen vanuit dropdown

De dropdown-header SHALL een knop bevatten die Planify opent/activeert.

#### Scenario: Knop klikken

- **WHEN** gebruiker op de open-knop in de dropdown-header klikt
- **THEN** wordt Planify gestart of naar voren gebracht via `uwsm app --`

---

### Requirement: Configureerbaar project en DB-pad

De module SHALL via `[modules.planify]` in `wayle.toml` configureerbaar zijn.

#### Scenario: Standaard configuratie

- **WHEN** geen `[modules.planify]` sectie aanwezig is
- **THEN** gebruikt de module project `"Inbox"` en het XDG-standaard DB-pad

#### Scenario: Aangepast project

- **WHEN** `project = "TN-ToDo"` ingesteld is
- **THEN** laadt de module alleen taken uit het project met die naam

#### Scenario: Aangepast DB-pad

- **WHEN** `db-path = "/custom/path/database.db"` ingesteld is
- **THEN** leest de module de database van dat pad

---

### Requirement: Automatisch verversen

De module SHALL taken automatisch herladen zonder handmatige actie.

#### Scenario: Polling interval

- **WHEN** 60 seconden zijn verstreken
- **THEN** herleest de module de SQLite database en werkt badge en dropdown bij
