## Context

Op malandro draaien statische sites als wereldvanbegrip (nginx-vhost, `/var/www/<site>`, gevuld door een `release.sh`). Login loopt daar via Authelia `main`, met gebruikers in Nix. Voor GrainWork wil de beheerder accounts via een GUI aanmaken voor mensen uit zijn netwerk, met passkeys; die mensen horen niet in dezelfde directory als de homelab-accounts.

## Goals / Non-Goals

**Goals:** site alleen voor groep `grainwork`; eigen IdP met GUI (Pocket ID); veilig opstarten (geen open `/setup`); alles declaratief behalve wat in de GUI hoort; getest zonder deploy.

**Non-Goals:** passkey-login automatisch testen; Authelia wijzigen.

## Decisions

### Architectuur

```
browser ─▶ nginx grainwork.dutchyland.net ── auth_request ─▶ oauth2-proxy 127.0.0.1:8099
              │ root /var/www/grainwork                           │ OIDC (code + PKCE S256)
              │ /welkom/, css, js, img, fontawesome,              ▼
              │ style.main.*.css, favicon, robots: zonder login   nginx id.dutchyland.net ─▶ Pocket ID 127.0.0.1:8098 ─▶ Postgres 16
```

- **Pocket ID i.p.v. een tweede Authelia + LLDAP**: één GUI voor gebruikers, groepen en clients, passkeys en mail-inlogcodes, uitnodigingslinks. Aparte IdP = harde scheiding van de homelab-accounts.
- **oauth2-proxy via `services.oauth2-proxy.nginx`**: zet `auth_request` op de hele vhost en `/oauth2/`-locaties; publieke paden krijgen `auth_request off`. Groepscontrole via `allowed_groups` (query op `/oauth2/auth`); daarnaast beperkt de OIDC-client in Pocket ID zich tot groep `grainwork`.
- **Client-id in het env-bestand**: Pocket ID genereert de client-id zelf, dus `OAUTH2_PROXY_CLIENT_ID` en `_SECRET` staan samen in `grainwork-oauth2-proxy-client.age` (`keyFile`).
- **Cookie** `_grainwork`, 30 dagen, `secure` bij TLS; `skip-provider-button` zodat je direct bij Pocket ID uitkomt.
- **Loopback**: Pocket ID met `HOST=127.0.0.1` (VM-test controleert dit), oauth2-proxy op `127.0.0.1:8099`.
- **Database**: de beheerder heeft een DB, gebruiker en wachtwoord. De connection string (`postgres://…@127.0.0.1:5432/…`) staat in agenix en gaat via systemd `LoadCredential` naar Pocket ID. De standaard-pg_hba van NixOS (`host all all 127.0.0.1/32 md5`) staat wachtwoord-logins over loopback al toe.

### Fasen en schakelaars

| Schakelaar         | Vereist                                       | Doet                                             |
|--------------------|-----------------------------------------------|--------------------------------------------------|
| `enable`           | CNAME `_acme-challenge.dutchyland.net`        | certificaat `*.dutchyland.net`                   |
| `pocketId.enable`  | `grainwork-pocket-id-db.age`                  | Pocket ID + vhost met setup-slot                 |
| `pocketId.setupLock` (standaard aan) | —                           | `allow` LAN/WG, `deny all` op `id.dutchyland.net` |
| `site.enable`      | `grainwork-oauth2-proxy-client.age` (uit GUI) | oauth2-proxy + site-vhost                        |

Zonder setup-slot kan iedereen via `/setup` de eerste admin worden zodra de wildcard-DNS naar malandro wijst. Het slot gaat pas uit na de setup.

### Tests

- `modules/grainwork_vmtest.nix` (`nix build .#checks.x86_64-linux.grainwork -L`): twee VM's. Controleert loopback-binding, Pocket ID via nginx, OIDC-discovery, 403 van buitenaf tijdens het setup-slot, 307 naar de login voor alle niet-publieke paden zonder dat inhoud lekt, 200 voor `/welkom/` en assets, en een autorisatie-redirect met client-id, scope `groups` en PKCE.
- `modules/grainwork_test.py`: evalueert de echte malandro-config met alle fasen aan (zonder deploy): agenix-paden, vhosts, setup-slot, publieke locaties, oauth2-proxy-instellingen, certificaat.

## Risks / Trade-offs

- **[Open `/setup`]** → setup-slot standaard aan; uitzetten is een bewuste stap na de setup.
- **[Pocket ID-instellingen in de GUI, niet in Nix]** → bewust (branding, SMTP, gebruikers); de DB zit in de bestaande `pg_dumpall`-backup.
- **[Encryption key kwijt = alle sessies/clients ongeldig]** → staat in agenix in de repo.
- **[Assets zonder login]** → bevatten geen studie-inhoud (afbeeldingen van studies kunnen herkenbaar zijn; acceptabel).
