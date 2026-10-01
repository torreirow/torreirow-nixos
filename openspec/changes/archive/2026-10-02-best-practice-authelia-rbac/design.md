# Design

## Context

Zie `proposal.md` — Why. Huidige staat (uit twee audits deze sessie):

- `modules/authelia.nix` `access_control`: `default_policy = deny`, een paar expliciete regels
  (kpn, linny, monitoring, users, network) **plus** een `*.toorren.net`-catch-all op `group:admins`
  die al het overige afvangt. Rule-order: kpn/linny staan vóór de wildcard; monitoring/users/network
  erná.
- Geen enkele backend leest de groep `admins` voor een in-app rol. `admins` = alleen de wildcard.
- Grafana (`modules/monitoring/grafana/grafana.nix`): `auth.proxy` met header `X-WEBAUTH-USER`,
  `users.auto_assign_org_role = "Admin"`, `root_url = http://192.168.2.52:3000`. Krijgt geen
  `Remote-Groups`. Gevolg: iedereen die binnenkomt wordt org-Admin.
- Paperless (`docs.toorren.net`): forward-auth → remote-user; superuser is een DB-vlag (nu `wouter`),
  `wouteruser` is er al een gewone gebruiker. Container draait buiten de repo.
- Accounts in `hosts/malandro/configuration.nix` (`services.authelia.users`): `wouter`
  (admins,users,monitoring,network,linny), `wouteruser` (users,monitoring,linny). users_database.yml
  is een **store-symlink** → groepen zijn declaratief, niet runtime te bewerken.

## Goals / Non-Goals

**Goals:**
- Deny-by-default echt waarmaken: geen wildcard, elke forward-auth-dienst een eigen regel.
- Een privileged admin-account (`wouteradmin`) gescheiden van dagelijkse accounts.
- Grafana's adminrol uit een echte groep halen i.p.v. "iedereen = Admin".
- Multi-user-klaar: nieuwe gebruikers krijgen een subset van groepen.

**Non-Goals:**
- Apps die buiten forward-auth staan (eigen login/OIDC) heringericht — die blijven zoals ze zijn.
- Group→rol-mapping voor apps die geen groep lezen (Paperless): geen `paperless-admins`-groep; de
  Paperless-superuser blijft een DB-vlag, nu runtime verzet naar `wouteradmin`.
- `kpn` en de bypass-regels (auth, kpn-lokaal) wijzigen.

## Decisions

### 1. Toegangsgroepen en de per-domein regeltabel (autoritatief)

| Domein (forward-auth) | Groep | Policy |
|------------------------------|------------------|-----------|
| prometheus.toorren.net | `monitoring` | two_factor |
| alertmanager.toorren.net | `monitoring` | two_factor |
| wg.toorren.net | `network` | two_factor |
| cockpit.toorren.net | `operations` | two_factor |
| fail2ban.toorren.net | `operations` | two_factor |
| status.toorren.net | `operations` | two_factor |
| zigbee2mqtt.toorren.net | `operations` | two_factor |
| pdftools.toorren.net | `operations` | two_factor |
| vw.toorren.net (`/admin`) | `operations` | two_factor |
| docs.toorren.net (paperless) | `office` | two_factor |
| contacts.toorren.net (baikal)| `office` | two_factor |
| mmdl.toorren.net | `office` | two_factor |
| ittools.toorren.net | `office` | two_factor |
| linny.toorren.net | `linny` | two_factor |
| wouter.toorren.net | `personal-wouter`| two_factor |
| agenda.toorren.net | `personal-wouter`| two_factor |

`grafana.toorren.net` staat NIET in deze tabel: het gaat op OIDC i.p.v. forward-auth (beslissing 3).
Bereik én rol lopen via de rol-groepen `grafana-admins`/`grafana-editors`, niet via `monitoring`
(dat blijft voorbehouden aan de rauwe prometheus/alertmanager-UI's). Zo kan iemand Grafana-Editor
zijn zonder bij de infra-monitoring te kunnen.

Behouden: `auth` (bypass) en de `kpn`-lokaal-bypass. De groep `users` vervalt (docs/contacts gaan
naar `office`), dus de `kpn`-externe regel verhuist van `group:users` naar `group:operations` (de
modem is een ops-taak). `linny-mcp` houdt zijn eigen OIDC-validator-pad (beslissing 5). Diensten
buiten forward-auth (vw-app, homeassistant,
nextcloud, vikunja, bookstack, wallos, erugo, chhoto, opsknight, publieke statische/redirect/API-
sites) krijgen **geen** regel — die raken `/api/verify` niet.

**Alternatief (verworpen): een `wildcard-toorren-net`/superuser-groep houden.** Dat herintroduceert
precies de impliciete "alles"-toegang die we wegnemen; de user koos expliciet voor volledig
expliciet.

### 2. Accountmodel

| Account | Groepen | Rol |
|--------------|-------------------------------------------------------|------------------------|
| `wouteradmin`| `monitoring`, `network`, `operations`, `office`, `grafana-admins` | privileged admin |
| `wouter` | `office`, `linny`, `personal-wouter`, `grafana-editors` | dagelijks, géén admin; Grafana-Editor |
| `wouteruser` | `office`, `linny` | gewone gebruiker |

`admins` verdwijnt volledig. `wouteradmin` krijgt `office` erbij zodat het Paperless kan bereiken en
daar superuser kan zijn (beslissing 4). `wouteradmin` heeft een **nieuwe argon2-hash** nodig (door
de user gekozen, one-time naar Vaultwarden) en doet **2FA-enrollment** bij eerste login.

### 3. Grafana: auth.proxy → OIDC op Authelia

- **Rol-/bereik-groepen**: `grafana-admins` (→ Admin) en `grafana-editors` (→ Editor). Beide geven
  tevens *bereik* tot Grafana; `monitoring` doet dat NIET (dat is alleen prometheus/alertmanager).
  Een toekomstige `grafana-viewers` kan view-only bereik geven; zonder lidmaatschap van een
  grafana-groep krijgt niemand toegang.
- **Authelia**: nieuwe confidential OIDC-client `grafana` (`modules/authelia.nix`): `redirect_uris =
  [ "https://grafana.toorren.net/login/generic_oauth" ]`, scopes incl. `groups`, een benoemde
  `authorization_policy` die lidmaatschap van `grafana-admins` OF `grafana-editors` (OF een latere
  `grafana-viewers`) vereist, client-secret-hash in de nix-config en het platte secret in een nieuw
  agenix-bestand `grafana-oidc-secret.age`.
- **Grafana** (`modules/monitoring/grafana/grafana.nix`): `auth.generic_oauth` aan met
  `client_id=grafana`, secret uit een file, `auth_url`/`token_url`/`api_url` van
  `auth.toorren.net`, `scopes = "openid profile email groups"`, en `role_attribute_path` dat
  `grafana-admins` → `Admin`, `grafana-editors` → `Editor`, anders `Viewer` mapt. `auth.proxy` +
  `auto_assign_org_role = Admin` **verwijderd**; `root_url` wordt `https://grafana.toorren.net`.
- **nginx** (`modules/monitoring/default.nix`): de `X-WEBAUTH-USER`-header en forward-auth op de
  grafana-vhost vervallen (Grafana doet zijn eigen OIDC-redirect; nginx proxyt alleen nog).
- **Let op**: Authelia moet de `groups`-claim leveren (scope `groups`). De exacte optienamen
  (`role_attribute_path`-expressie, Authelia-claim-config) worden in de apply-fase geverifieerd
  tegen de draaiende versies; dit design legt de *bedoeling* vast.

**Alternatief (verworpen): auth.proxy + X-WEBAUTH-ROLE-header.** Blijft header-trust en vereist dat
nginx per gebruiker een rol berekent — broos. OIDC is de Authelia-aanbeveling en Authelia draait al
als provider.

### 4. Paperless-rollen (runtime)

Paperless leest geen Authelia-groep voor superuser; het is een DB-vlag per (remote-)user. Daarom
**geen** `paperless-admins`-groep. Runtime op malandro (container buiten de repo):
- `wouteradmin` één keer laten inloggen (remote-user → Paperless-user aangemaakt), daarna
  `is_superuser`/`is_staff` = true zetten.
- `wouter` → `is_superuser`/`is_staff` = false (gedegradeerd tot gewone gebruiker).
- `wouteruser` → ongewijzigd gewone gebruiker.

Tot deze stap is gedaan blijft `wouter` Paperless-superuser, terwijl hij op Authelia-niveau al geen
admin meer is. Dat venster is bewust en kort.

### 5. linny → groep hernoemen

`LinnyWouter` → `linny` in: de access_control-regel voor `linny.toorren.net`, de
`authorization_policies.linny-mcp-write`-subject (`modules/authelia.nix`), en de groepslijsten van de
accounts. `modules/linny-mcp.nix` commentaar bijwerken. De `linny-mcp-oidc`-spec wijzigt mee.

## Risks / Trade-offs

- **Lockout bij verkeerde volgorde** → gemitigeerd: groepen/accounts + álle expliciete regels in
  dezelfde commit/switch als het verwijderen van de wildcard; per-domein verificatie uit de
  inventaris; geteste rollback (vorige generation).
- **`wouteradmin` zonder werkend wachtwoord/2FA = buitengesloten admin** → de hash moet kloppen
  vóór de switch; 2FA-enrollment kan ná de switch via het portaal, want het account kan al met
  wachtwoord+een-factor inloggen om te enrollen (afhankelijk van de 2FA-policy — verifiëren).
- **Grafana: bestaande org-Admins/users opnieuw** → na de OIDC-omzet logt iedereen opnieuw in; de
  oude `auth.proxy`-user `wouter` (Admin) blijft als wees. Dashboards/datasources zijn
  geprovisioned, dus niet verloren; persoonlijke voorkeuren onder de oude user wel.
- **Einde "iedereen = Grafana-Admin"** is gewenst maar breekt impliciet gedrag: een `monitoring`-lid
  dat geen `grafana-admins` is wordt Viewer. Bewust.
- **Paperless-degradatie van wouter** → als de runtime-stap faalt, kan wouter tijdelijk nog
  superuser zijn; geen beveiligingsgat, wel inconsistent met de bedoeling. Verifiëren.

## Migration Plan

Eén `nixos-rebuild switch`, in deze volgorde binnen dezelfde commit:
1. Secrets: `grafana-oidc-secret.age` + recipient in `secrets.nix`; `wouteradmin` argon2-hash.
2. Accounts: `wouteradmin` toevoegen, `wouter`/`wouteruser` groepen herzien, `admins` weg.
3. access_control: alle expliciete per-domein regels toevoegen (incl. de gaten alertmanager/agenda),
   `linny`-hernoeming, wildcard verwijderen. Rule-order: specifiek vóór algemeen; bypass behouden.
4. Grafana OIDC-client + Grafana-settings + nginx-vhost.
5. `switch`, dan **per-domein verifiëren** (elk domein uit de inventaris: komt het juiste account
   wel/niet binnen zoals bedoeld).
6. Runtime: Paperless superuser → `wouteradmin`, `wouter` degraderen; `wouteradmin` 2FA-enrollment.

**Rollback**: `nixos-rebuild switch` naar de vorige generation herstelt access_control, accounts en
Grafana in één stap (users_database.yml en authelia-config zijn declaratief). De Paperless-DB-stap
is apart terug te draaien (superuser-vlaggen omzetten).

## Open Questions

- **2FA-policy bij eerste login van `wouteradmin`**: of enrollment ná de switch kan zonder al 2FA te
  hebben, hangt van de actieve policy af — verifiëren in de apply-fase; verandert de aanpak niet.
