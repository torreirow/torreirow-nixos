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

- [ ] Switch op malandro; `authelia-main` moet actief blijven
- [ ] **Regressie: de andere Authelia-vhosts.** `linny`, `status`, `grafana`,
      `homeassistant` en `subscriptions` (Wallos, inloggen doorlopen) moeten
      gewoon werken. Een wijziging in dit bestand legde ze eerder vier minuten plat
- [ ] Nulpunt vastleggen uit `/var/lib/authelia-main/db.sqlite3`:

        select count(*) from oauth2_authorization_code_session
          where client_id='claude-connector';

- [ ] Connector opnieuw koppelen; daarna toont de eerste ronde nog wél een
      toestemmingsscherm (de onthouden toestemming moet eerst ontstaan)
- [ ] Na enkele dagen hertellen: bij dagelijks gebruik hoort het aantal
      autorisatiecodes NIET te stijgen. Stijgt het wel, dan klopt de aanname over
      rotatie niet en moet dat in `design.md`
- [ ] Redis-sessies opnieuw tellen: het aantal hoort te stabiliseren in plaats
      van door te groeien
