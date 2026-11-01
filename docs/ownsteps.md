# OwnSteps (reis.toorren.net) — reisblog als Polarsteps-vervanger

OCI-container op poort 8089, data in `/data/external/ownsteps`, géén Authelia. Proefopzet.

### Sessie 2026-10-30 - Proefopzet

**Waarom OwnSteps:** het open-source alternatief dat het meest gericht is op de thuisblijvers.
Die krijgen een geheime deellink (optioneel met wachtwoord) zonder account, met tijdlijn + kaart,
schermvullende foto/video's, reageren met alleen een naam, en een offline album als export. Vanaf
0.6.0 krijgen volgers in de app een melding bij een nieuwe stap. Afgewogen tegen MarkMySteps (sterk
in GPS-tracking, maar geen tekst per stap), Dawarich (locatiegeschiedenis, geen blog) en
AdventureLog (reisplanner, geen Android-app).

**Beperkingen:** geen continue GPS-route; de plek van een stap komt uit de EXIF van foto's, een
knop voor de huidige locatie of de kaart. Jong project (1 ontwikkelaar).

**Configuratie (`modules/ownsteps.nix`):**
- Image `ghcr.io/rainerzufall00/ownsteps:0.6.0`, vastgepind. Upgraden: CHANGELOG lezen en tag
  ophogen (tags `0.x.y`, `0.x`, `latest`).
- `127.0.0.1:8089:2555`; volume `/data/external/ownsteps:/data` (SQLite `ownsteps.db`, uploads,
  `.secret` met de zelf gegenereerde `APP_SECRET`).
- `secrets/ownsteps-env.age`: `ADMIN_EMAIL`, `ADMIN_PASSWORD`, `ADMIN_NAME`. Maakt het eerste
  account bij de allereerste start, zodat de setup niet open op internet staat.
- nginx: `client_max_body_size 500M` (video's tot 400 MB), `proxy_request_buffering off`.
- **Geen Authelia**: deellinks moeten publiek zijn, en de Android-app gebruikt `/api/v1` met een
  bearer-token. Een forward-auth ervoor breekt beide.

**Nog niet gedaan:**
- Niet in de rustic-backup. Bij definitief gebruik: `/data/external/ownsteps` toevoegen, met
  een SQLite-dump (zoals Vaultwarden) i.p.v. de live `ownsteps.db`.
- Android-app: offline stappen maken en later synchroniseren is niet getest.
