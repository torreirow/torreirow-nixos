# Paperless-ngx (docs.toorren.net)

Sinds 2026-10-27 als NixOS `virtualisation.oci-containers` in `modules/paperless.nix`; daarvoor een
handmatige `docker compose`-stack in `/data/external/tmp/paperless/paperless-ngx`.

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
  zat dus niet in de rustic-backup; nu een bind mount onder `/data/external/tmp/paperless`.
- **Geen aanhalingstekens in het env-bestand**: `docker --env-file` neemt ze letterlijk over (compose
  stripte ze). De secret key stond tussen aanhalingstekens.

## Restanten van de compose-stack (opruimen als alles een tijd goed draait)

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
