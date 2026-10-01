# Tasks

## 1. Secrets en het admin-wachtwoord

- [x] 1.1 `wouteradmin` argon2-hash genereren: `authelia crypto hash generate argon2 --password
  '<gekozen-wachtwoord>'` (sterk, willekeurig; one-time naar Vaultwarden). Verifieer dat de hash met
  `$argon2id$` begint. Het platte wachtwoord komt NIET in git.
- [x] 1.2 Grafana-OIDC client-secret genereren en als agenix-secret opslaan
  `secrets/grafana-oidc-secret.age` (het platte secret voor Grafana's env), plus de argon2-hash
  ervan voor de Authelia-client. Secret schrijven via stdin (`cd secrets && ragenx -e
  grafana-oidc-secret.age --ssh-dir /etc/ssh < plain`). Verifieer met `ragenx -d`.
- [x] 1.3 Recipient-regel voor `grafana-oidc-secret.age` in `secrets/secrets.nix` (zelfde recipients
  als andere malandro-secrets). Verifieer dat `ragenx -e` zonder "no rule"-fout werkt.

## 2. Accounts en groepen (declaratief)

- [x] 2.1 In `hosts/malandro/configuration.nix` (`services.authelia.users`): account `wouteradmin`
  toevoegen (hash uit 1.1), groepen `monitoring network operations office grafana-admins`.
- [x] 2.2 `wouter` herzien → groepen `office linny personal-wouter grafana-editors` (admins +
  monitoring + network eraf; grafana-editors erbij voor Editor-rol). `wouteruser` → `office linny`
  (users + monitoring eraf; LinnyWouter→linny). Verifieer met `nix eval` dat de drie accounts de
  bedoelde groepen hebben en `admins` nergens meer voorkomt.

## 3. access_control opnieuw inrichten

- [x] 3.1 In `modules/authelia.nix` `access_control.rules`: de `*.toorren.net`-wildcardregel
  (`group:admins`) verwijderen en expliciete per-domein regels toevoegen conform de tabel in
  design.md (monitoring: prometheus+alertmanager; network: wg; operations: cockpit/fail2ban/status/
  zigbee2mqtt/pdftools/vw`/admin`; office: docs/contacts/mmdl/ittools; personal-wouter: wouter+agenda).
  Dicht de gaten alertmanager en agenda. Grafana valt NIET meer onder een access_control-regel maar
  onder de OIDC-client (groep 4). Bypass-regels (auth, kpn) ongemoeid; rule-order: specifiek vóór
  algemeen.
- [x] 3.2 `authorization_policies.linny-mcp-write`-subject en de `linny.toorren.net`-regel naar
  `group:linny` (hernoeming van LinnyWouter). Verifieer met `nix eval` dat er geen `*.toorren.net`-
  regel meer bestaat en elk forward-auth-domein uit de inventaris een regel heeft.

## 4. Grafana van auth.proxy naar OIDC

- [x] 4.1 In `modules/authelia.nix` een confidential OIDC-client `grafana` toevoegen: redirect_uri
  `https://grafana.toorren.net/login/generic_oauth`, scopes incl. `groups`, client-secret-hash uit
  1.2, en een benoemde `authorization_policy` die lidmaatschap van `grafana-admins` OF
  `grafana-editors` vereist (bereik; `monitoring` geeft GEEN Grafana-toegang).
- [x] 4.2 In `modules/monitoring/grafana/grafana.nix`: `auth.proxy` + `auto_assign_org_role=Admin`
  verwijderen; `auth.generic_oauth` aanzetten (client_id `grafana`, secret uit file, auth/token/api-
  urls van `auth.toorren.net`, scopes `openid profile email groups`, `role_attribute_path` dat
  `grafana-admins`→Admin, `grafana-editors`→Editor mapt, anders Viewer); `root_url =
  https://grafana.toorren.net`.
- [x] 4.3 In `modules/monitoring/default.nix` de grafana-vhost: `X-WEBAUTH-USER` + forward-auth
  verwijderen (Grafana doet eigen OIDC-redirect; nginx proxyt alleen). Verifieer met `nixos-rebuild
  build .#malandro` dat de config bouwt en Grafana-settings `generic_oauth` bevatten, geen
  `auth.proxy`.

## 5. linny-mcp consistentie + spec-sync

- [x] 5.1 `modules/linny-mcp.nix`: commentaren die `group:admins`/`LinnyWouter` noemen bijwerken naar
  `group:linny`. Verifieer met grep dat er geen `LinnyWouter`/`group:admins` meer in de module staat.

## 6. Configuratie-verificatie (build, zonder deploy)

- [x] 6.1 `nix eval` script dat per forward-auth-domein uit de inventaris nagaat dat (a) er een regel
  bestaat, (b) geen `*.toorren.net`-regel bestaat, (c) de drie accounts de bedoelde groepen hebben,
  (d) de grafana OIDC-client en linny→`group:linny` kloppen. Draai het groen vóór de switch.

## 7. Deploy en lockout-veilige live verificatie

- [x] 7.1 `sudo nixos-rebuild switch --flake .#malandro`. Authelia + nginx + grafana komen schoon op
  (`systemctl is-active`, geen configfouten in de authelia-log).
- [x] 7.2 Per-domein live verifiëren uit de inventaris: `wouteradmin` komt bij de operations/
  monitoring/network-diensten; `wouter` wordt daar geweigerd maar komt wél bij office/linny/personal;
  `linny-mcp` schrijven werkt met `group:linny`. Bevestig dat geen enkel beoogd domein per ongeluk
  dichtviel. Houd de vorige generation als rollback bij de hand.
- [ ] 7.3 Grafana-login via OIDC testen: `wouteradmin` → Admin; een `monitoring`-only testgebruiker
  (of redenering) → Viewer; `wouter` (geen monitoring) → geen toegang. Bevestig dat de oude
  "iedereen = Admin" weg is.

## 8. Paperless-rollen (runtime, buiten repo)

- [x] 8.1 `wouteradmin` één keer in Paperless laten inloggen (remote-user → user aangemaakt), daarna
  `is_superuser`/`is_staff` = true zetten (Paperless-container, django/admin). Verifieer dat
  `wouteradmin` superuser is.
- [x] 8.2 `wouter` in Paperless degraderen: `is_superuser`/`is_staff` = false; `wouteruser`
  ongewijzigd gewone gebruiker. Verifieer dat `wouter` geen superuser meer is en zijn documenten
  intact zijn.

## 9. Documentatie

- [x] 9.1 `docs/linny-mcp.md`: `group:LinnyWouter` → `group:linny` overal; route-/slot-tabellen bij.
- [x] 9.2 `CHANGELOG.md` (NEXT VERSION) + `CLAUDE.md`-sessie-entry: het nieuwe autorisatiemodel
  (expliciete regels, groepen, wouteradmin-scheiding, Grafana-OIDC, Paperless-herkoppeling),
  inclusief de lockout-veilige migratie en de store-symlink-les van de users-db.
