---
# nixos-3no7
title: Uitrollen en meten dat het werkt
status: in-progress
type: task
priority: normal
created_at: 2026-09-29T20:00:28Z
updated_at: 2026-09-29T20:08:48Z
parent: nixos-b25k
---

De bewering is "bij dagelijks gebruik nooit meer opnieuw autoriseren". Dat is
alleen over tijd vast te stellen, dus meet het nulpunt en kom terug.

- [x] Switch op malandro; `authelia-main` moet actief blijven
- [x] **Regressie: de andere Authelia-vhosts.** `linny`, `status`, `grafana`,
      `homeassistant` en `subscriptions` (Wallos, inloggen doorlopen) moeten
      gewoon werken. Een wijziging in dit bestand legde ze eerder vier minuten plat
- [x] Nulpunt vastleggen uit `/var/lib/authelia-main/db.sqlite3`:

        select count(*) from oauth2_authorization_code_session
          where client_id='claude-connector';

- [ ] Connector opnieuw koppelen; daarna toont de eerste ronde nog wél een
      toestemmingsscherm (de onthouden toestemming moet eerst ontstaan)
- [ ] Na enkele dagen hertellen: bij dagelijks gebruik hoort het aantal
      autorisatiecodes NIET te stijgen. Stijgt het wel, dan klopt de aanname over
      rotatie niet en moet dat in `design.md`
- [ ] Redis-sessies opnieuw tellen: het aantal hoort te stabiliseren in plaats
      van door te groeien


## Stand 2026-09-29

Uitgerold en geverifieerd voor zover dat nu kan.

    nulpunt 22:08:48    7 autorisatiecodes · 9 toestemmingen · 1324 redis-sessies
    switch              authelia-main actief
    regressie           auth 200 · linny 302 · status 302 · grafana 302
                        homeassistant 200 · subscriptions 302
    wallos              autorisatieverzoek geeft 303 naar de inlogpagina,
                        erft het lifespan-profiel niet
    connector           /mcp zonder token nog steeds 401

## Wat er nog moet gebeuren

[ ] **Connector opnieuw koppelen** (handwerk). De eerste ronde na deze wijziging
    toont nog één keer een toestemmingsscherm — die moet eerst ontstaan voordat
    hij onthouden kan worden.

[ ] **Na enkele dagen hertellen.** Dit is de eigenlijke toets; de belofte is niet
    op het moment van uitrollen te bewijzen.

        sudo sqlite3 /var/lib/authelia-main/db.sqlite3 \
          "select count(*) from oauth2_authorization_code_session
             where client_id='claude-connector';"

    Bij dagelijks gebruik hoort dat getal na de eerstvolgende koppeling NIET meer
    te stijgen. Stijgt het wel, dan klopt de aanname over rotatie niet en hoort
    dat in design.md van `tune-connector-session` — niet weggepoetst. Tel ook de
    redis-sessies: die horen te stabiliseren in plaats van door te groeien.
