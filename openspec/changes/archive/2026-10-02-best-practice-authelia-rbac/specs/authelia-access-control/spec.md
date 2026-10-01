# Spec Delta

## Purpose

Legt het autorisatiemodel vast waarmee malandro's Authelia toegang tot vhosts regelt: expliciete
per-domein toegang op betekenisvolle groepen (deny-by-default, geen wildcard), een privileged
admin-account gescheiden van dagelijkse accounts, en group→rol-mapping alleen waar een app die
rol daadwerkelijk leest.

## ADDED Requirements

### Requirement: Toegang is expliciet per domein, zonder wildcard

Elke dienst die achter Authelia forward-auth staat SHALL via een expliciete per-domein
`access_control`-regel aan een benoemde groep (of een bypass-conditie) worden toegekend. Er SHALL
geen regel zijn die op een domein-wildcard (`*.toorren.net`) diensten impliciet ontsluit, en de
`default_policy` SHALL `deny` zijn.

#### Scenario: Een dienst zonder expliciete regel is dicht

- **WHEN** een forward-auth-beschermd domein geen eigen `access_control`-regel heeft
- **THEN** Authelia SHALL de toegang weigeren op grond van `default_policy = deny`
- **AND** er SHALL geen wildcard-regel bestaan die de dienst alsnog ontsluit

#### Scenario: Elke actieve forward-auth-dienst heeft een regel

- **WHEN** de access_control-regels worden vergeleken met de forward-auth-beschermde vhosts
- **THEN** elke zulke vhost SHALL door precies één expliciete domein-regel (of een bypass) worden
  gedekt

### Requirement: Een privileged admin-account is gescheiden van dagelijkse accounts

Administratieve diensten (infrastructuur, monitoring, netwerkbeheer) SHALL alleen toegankelijk zijn
voor een apart privileged account, niet voor een dagelijks gebruikersaccount. Een dagelijks account
SHALL geen toegang hebben tot die administratieve diensten.

#### Scenario: Dagelijks account komt niet bij admintools

- **WHEN** het dagelijkse account een administratieve dienst (bijvoorbeeld `cockpit`,
  `fail2ban` of `alertmanager`) opvraagt
- **THEN** Authelia SHALL de toegang weigeren omdat dat account niet in de bijbehorende groep zit

#### Scenario: Admin-account komt wel bij admintools

- **WHEN** het privileged admin-account dezelfde administratieve dienst opvraagt en 2FA doorloopt
- **THEN** Authelia SHALL de toegang verlenen

### Requirement: In-app adminrol hangt aan een expliciete rol-groep waar de app die leest

Waar een applicatie een in-app rol uit een groep kan afleiden SHALL de adminrol aan een expliciete
rol-groep hangen, en de applicatie SHALL NOT elke binnenkomende gebruiker automatisch de adminrol
geven. Voor een applicatie die geen groep voor zijn rol leest SHALL er GEEN groep voor die rol
worden gedefinieerd; de rol wordt dan in de applicatie zelf toegekend.

#### Scenario: Grafana-rol volgt de rol-groep

- **WHEN** een gebruiker Grafana opent die lid is van de Grafana-adminrol-groep
- **THEN** Grafana SHALL de rol Admin toekennen
- **AND** een gebruiker die wel Grafana mag openen maar niet in die rol-groep zit SHALL een
  niet-admin rol (Viewer/Editor) krijgen, niet automatisch Admin

#### Scenario: Geen lege rol-groep voor een app die groepen negeert

- **WHEN** een applicatie zijn adminrol niet uit een Authelia-groep afleidt (de rol staat in de
  app-database)
- **THEN** het model SHALL geen Authelia-groep voor die adminrol definiëren
- **AND** de rol SHALL in de applicatie zelf aan het admin-account worden toegekend
