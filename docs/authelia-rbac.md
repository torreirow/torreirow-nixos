# Authelia best-practice RBAC + Grafana OIDC (malandro)

access_control per groep, gescheiden accounts (wouteradmin/wouter/wouteruser), Grafana via OIDC en de vier 'Viewer i.p.v. Admin'-valkuilen.

> Verplaatst uit CLAUDE.md (Huidige Status) om de sessie-context slank te houden.

### Sessie 2026-10-01 - Authelia best-practice RBAC op malandro - LIVE EN GETEST

**Doel:** Autorisatie multi-user-klaar maken. OpenSpec change `best-practice-authelia-rbac`.
Aanleiding: twee audits deze sessie toonden dat (1) GEEN backend de `admins`-groep op een in-app
adminrol mapt — `admins` deed enkel de `*.toorren.net`-wildcard; (2) Grafana iederéén die binnenkwam
org-Admin gaf (auth.proxy + auto_assign_org_role=Admin).

**Doorgevoerd (generation 54+, live):**
- **access_control volledig expliciet** (`modules/authelia.nix`): wildcard + groep `admins` weg;
  per-domein regels op groepen `monitoring` (prometheus, alertmanager), `network` (wg), `operations`
  (cockpit, fail2ban, status, zigbee2mqtt, pdftools, vw`/admin`), `office` (docs, contacts, mmdl,
  ittools), `linny` (webview), `personal-wouter` (wouter.toorren.net, agenda). kpn-extern → operations.
  Gaten alertmanager/agenda gedicht. **LinnyWouter → linny** (policy + regel + spec).
- **Gescheiden accounts** (`hosts/malandro/configuration.nix` → store-symlink users-db, declaratief):
  nieuw **wouteradmin** (monitoring/network/operations/office/grafana-admins); **wouter** gedegradeerd
  (office/linny/personal-wouter/grafana-editors, GEEN admin); **wouteruser** (office/linny).
- **Grafana → OIDC** (`modules/monitoring/grafana/grafana.nix` + `default.nix`): auth.proxy +
  auto_assign_org_role=Admin eruit; generic_oauth op Authelia met `role_attribute_path`
  (grafana-admins→Admin, grafana-editors→Editor, anders Viewer); nieuwe Authelia-client `grafana` +
  policy (grafana-admins OF grafana-editors, **nested lijst = OR**); `grafana-oidc-secret.age`;
  ingebouwde admin-login als vangnet aan. root_url → publiek.

**Twee valkuilen onderweg (opgelost):**
- Grafana-settings-sectie moet een **quoted dotted key** zijn: `settings."auth.generic_oauth"`, niet
  genest — anders "not of type INI atom".
- **Dubbele Host-header → Grafana 400.** `recommendedProxySettings` zet al `Host $host`; mijn eigen
  `proxy_set_header Host $host` erbovenop gaf twee Host-headers → Go weigert (400). Handmatige headers
  op de grafana-vhost weggehaald. Loopback (één Host) gaf wél 302 — zo gevonden.

**CLI-geverifieerd:** build OK; `nix eval` → geen wildcard, `admins` nergens, alle 17 forward-auth-
domeinen gedekt, accounts/groepen correct; Authelia "loaded successfully"; Grafana `/`→302→/login met
de Authelia-knop; alertmanager 302 (gated). **Secrets via stdin**, geen newline in het OIDC-secret
(anders hash-mismatch).

**Grafana-OIDC — vier valkuilen die ALLE vier "Viewer i.p.v. Admin" gaven (volgorde van ontdekken):**
1. **client-auth-methode mismatch.** Grafana stuurt `client_secret_basic`; de Authelia-client stond op
   `client_secret_post` → token-exchange faalt ("token is not in JWT format" aan Grafana-kant). Zet de
   client op `client_secret_basic`.
2. **JMESPath op een PLATTE lijst.** `contains(groups[*], 'x')` faalt stil op een platte stringlijst
   (`groups[*]` = projectie). Gebruik `contains(groups, 'x')` ZONDER `[*]`. (Los getest met `jp`.)
3. **Grafana leest de rol uit het ID-TOKEN, Authelia zet `groups` standaard alleen in de userinfo.**
   Daardoor zag `role_attribute_path` geen groups in het id_token en gaf de `|| 'Viewer'`-fallback altijd
   Viewer. Fix: Authelia **`claims_policies.grafana.id_token = [groups email ...]`** + `claims_policy =
   "grafana"` op de client → groups in het id_token.
4. **Oude users + gewijzigd subject.** De oude auth.proxy had al Grafana-users (zonder echt e-mailadres);
   OIDC kon niet koppelen → "Failed to create user: user not found". Fix: `oauth_allow_insecure_email_
   lookup = true` (één vertrouwde provider) + user2-email rechtgezet + verouderde oauth_generic_oauth-
   koppeling uit grafana.db gewist. **Let op:** een **cached sessie** pakt de nieuwe rol NIET — volledig
   uitloggen + verse OIDC-login nodig.

**Getest (browser):** wouteradmin → **Grafana-Admin** (groups in id_token bevestigd); wouter geweigerd
bij cockpit/prometheus (403), wél bij docs; wouter wordt Editor bij verse login. **Paperless (runtime):**
wouteradmin = superuser; wouter gedegradeerd maar via object-rechten ziet die nog alle 63 docs
(`guardian assign_perm documents.view_document`). Superusers nu: paperlessadmin, wvandertoorren,
wouteradmin. Rollback = `nixos-rebuild switch` naar generation 53/555.

**Status:** ✅ Live en getest. Alleen nog: change archiveren + PR/merge.
