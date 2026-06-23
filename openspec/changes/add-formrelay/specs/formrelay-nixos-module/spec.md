## ADDED Requirements

### Requirement: NixOS module met declaratieve configuratie
De module `modules/formrelay.nix` SHALL een `services.formrelay` attribuutset aanbieden waarmee de service volledig declaratief kan worden geconfigureerd.

#### Scenario: Module inschakelen met minimale configuratie
- **WHEN** `services.formrelay.enable = true` en `services.formrelay.hcaptchaSecretFile` zijn ingesteld met minstens één form token
- **THEN** start de service als systemd unit en is het `/submit` endpoint bereikbaar op `127.0.0.1:8094`

#### Scenario: Module uitgeschakeld
- **WHEN** `services.formrelay.enable = false` (standaard)
- **THEN** worden er geen systemd units of nginx virtual hosts aangemaakt

### Requirement: Configureerbare module opties
De module SHALL de volgende opties aanbieden:

- `enable` (bool, default: false): schakel de service in
- `port` (int, default: 8094): luisterpoort op localhost
- `hcaptchaSecretFile` (path): pad naar bestand met hCaptcha secret key (agenix secret)
- `fromAddress` (string, default: `"forms@toorren.net"`): afzender emailadres
- `forms` (attribuutset): map van token string naar form configuratie met:
  - `name` (string): leesbare naam
  - `to` (string): ontvanger emailadres
  - `allowedOrigins` (list of strings): toegestane origins

#### Scenario: Meerdere tokens configureren
- **WHEN** `services.formrelay.forms` meerdere tokens bevat (bijv. voor `wereldvanbegrip.nl` en `boaz.toorren.net`)
- **THEN** verwerkt één service instantie alle tokens correct

#### Scenario: hCaptcha secret via agenix
- **WHEN** `hcaptchaSecretFile = config.age.secrets.hcaptcha-secret.path` is ingesteld
- **THEN** leest de service de secret key uit dat bestand bij opstarten

### Requirement: Nginx virtual host voor forms.toorren.net
De module SHALL automatisch een nginx virtual host aanmaken voor `forms.toorren.net` die proxiet naar de lokale service.

#### Scenario: Nginx virtual host aangemaakt
- **WHEN** `services.formrelay.enable = true`
- **THEN** is `https://forms.toorren.net/submit` bereikbaar via nginx met TLS (via bestaand wildcard certificaat `*.toorren.net`)

#### Scenario: Nginx rate limiting toegepast
- **WHEN** de nginx virtual host wordt aangemaakt
- **THEN** is de bestaande `limit_req_zone` rate limiting van toepassing op het `/submit` endpoint

### Requirement: Go binary gebouwd met buildGoModule
De formrelay binary SHALL worden gebouwd als Nix derivation via `pkgs.buildGoModule` vanuit broncode in `pkgs/formrelay/`.

#### Scenario: Binary beschikbaar als package
- **WHEN** `pkgs.callPackage ./pkgs/formrelay {}` wordt aangeroepen
- **THEN** wordt een compileerbare Go binary geproduceerd die als `ExecStart` in de systemd unit kan worden gebruikt

#### Scenario: Reproduceerbare build
- **WHEN** de broncode niet verandert
- **THEN** produceert de Nix build dezelfde binary hash (reproduceerbaar via `vendorHash`)
