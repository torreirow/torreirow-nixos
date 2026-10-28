# Paperless-ngx (docs.toorren.net)

Sinds 2026-10-27 als NixOS `virtualisation.oci-containers` in `modules/paperless.nix`; daarvoor een
handmatige `docker compose`-stack. De map staat sinds 2026-10-27 op `/data/external/paperless-ngx`
(daarvoor `/data/external/tmp/paperless/paperless-ngx`; verplaatst met `mv` op dezelfde schijf).

## Waarom omgezet

Na de reboot van 2026-10-17 startte de compose-broker niet (`failed to set up container networking:
network 9476… not found`). Docker herstart zo'n container nooit, ook niet met `unless-stopped`. De
webserver zat daarna 10 dagen in een herstart-lus (10.552×): paperless onbereikbaar en ~0,8 kern
extra user-CPU (zichtbaar als sprong in CPU en temperatuur in het Server Health-dashboard). De interne
probe `127.0.0.1:8181` stond al die tijd op 0 en "Internal Service Down" vuurde, maar viel weg tussen
de andere reboot-meldingen.

## Opzet

| Onderdeel             | Waarde                                                                 |
|-----------------------|------------------------------------------------------------------------|
| Netwerk               | `paperless`, 172.18.0.0/16, gw 172.18.0.1 (`init-paperless-net.service`) |
| Broker                | `paperless-broker` (redis:8), named volume `paperless_redisdata`        |
| Webserver             | `paperless-webserver`, `127.0.0.1:8181` → 8000                          |
| Database              | Postgres op de host via 172.18.0.1 (pg_hba in `modules/postgres.nix`)   |
| Geheimen              | `secrets/paperless-env.age`: `PAPERLESS_SECRET_KEY`, `PAPERLESS_DBPASS` |
| Mappen (bind)         | `consume`, `media`, `export`, `data` onder de map hierboven             |

- Het **vaste subnet** is nodig voor Postgres (pg_hba + `PAPERLESS_DBHOST`). `init-paperless-net`
  maakt het netwerk vóór de containers aan als het ontbreekt.
- **Alleen loopback**: Paperless vertrouwt de `Remote-User`-header van nginx/Authelia. Onder compose
  stond de poort op `0.0.0.0:8181`, waardoor iedereen in het LAN de header kon vervalsen.
- **`data`** (index, classificatiemodel, celerybeat) was onder compose een anoniem docker-volume en
  zat dus niet in de rustic-backup; nu een bind mount onder `/data/external/paperless-ngx`.
- **Geen aanhalingstekens in het env-bestand**: `docker --env-file` neemt ze letterlijk over (compose
  stripte ze). De secret key stond tussen aanhalingstekens.

## Gebruikers en rechten (runtime, in de Paperless-database)

Authelia laat de groep `office` door naar `docs.toorren.net`. Paperless maakt bij de eerste login
via `Remote-User` een gebruiker aan, maar **zonder rechten**: je kunt dan niets uploaden.

| Gebruiker                                   | Rechten                                             |
|---------------------------------------------|-----------------------------------------------------|
| `wouteradmin`, `paperlessadmin`, `wvandertoorren` | superuser                                     |
| `wouter`                                    | Paperless-groep `office` + `view_*` uit 2026-10-01  |

De Paperless-groep **`office`** (aangemaakt 2026-10-27) geeft view/add/change/delete op document,
tag, correspondent, documenttype, storagepath, note, savedview(+filterrule), customfield(+instance),
sharelink en uisettings, plus view/change op paperlesstask (uploadstatus). Geen beheerrechten
(users, groepen, mail, workflows). Een nieuwe gebruiker hoef je alleen aan de groep toe te voegen:

```bash
sudo docker exec paperless-webserver python3 /usr/src/paperless/src/manage.py shell -c "
from django.contrib.auth.models import User, Group
User.objects.get(username='NAAM').groups.add(Group.objects.get(name='office'))"
```

Let op: wijzigen of verwijderen van een document van **iemand anders** vraagt daarnaast
objectrechten op dat document (eigenaar/rechten in de documentweergave). Eigen uploads zijn van
de uploader.

## Restanten van de compose-stack (opruimen als alles een tijd goed draait)

- ~~Containers `paperless-webserver-1` en `paperless-broker-1`~~ **verwijderd 2026-10-28.** Ze draaiden
  (`restart=unless-stopped`) van 23 okt tot de reboot van 28 okt naast de Nix-containers, met de oude
  mappen onder `/data/external/tmp/paperless/` en poort 8181. Volumes en mappen zijn blijven staan.

- `docker-compose.yml.migrated-to-nix` en `docker-compose.env` (bevat nog de geheimen in platte tekst)
  in de paperless-map.
- Anoniem volume `6dbeb322789b…` (oude data-map, gekopieerd naar `data/`): `docker volume rm 6dbeb322789b998690557406692c7aab951106727b17fae6c122c07a506a4d55`.
- Oude data-bestanden uit januari in de root van de paperless-map (`index/`, `classification_model.pickle`,
  `celerybeat-schedule.db`, `documents/`, `log/`) — van vóór het anonieme volume, niet meer in gebruik.

## Controleren

```bash
sudo docker ps --filter name=paperless
sudo docker inspect -f '{{.State.Health.Status}}' paperless-webserver
sudo docker logs --since 10m paperless-webserver | grep -iE "error|redis|ready"
sudo -u postgres psql -d paperless -Atc "select count(*) from documents_document;"
```
