---
# nixos-nuty
title: 'maaike: seeds (Nextcloud, Bitwarden) + herstel-app'
status: completed
type: task
priority: normal
created_at: 2026-11-04T21:10:32Z
updated_at: 2026-11-05T08:36:17Z
parent: nixos-kzxu
blocked_by:
    - nixos-8tac
---

Seeds + `herstel-app`.
- Seed-mechanisme: HM-activatie of systemd-user-oneshot die een bestand uit de store kopieert ALLEEN als het doel ontbreekt (schrijfbaar, eigenaar maaike).
- Seeds: Nextcloud (`nextcloud.cfg`), Bitwarden desktop (server-URL), later ZapZap/Signal uit `home/profiles/maaike/defaults/`.
- `herstel-app <gebruiker> <app|all>`: stop app (pkill voor die user), backup `*.bak-<datum>`, seed opnieuw; voor spotify: `systemctl restart agenix` of de juiste activatie zodat prefs terugkomt. Duidelijke foutmelding bij onbekende app.


- Bestaat al (sinds a563af2+): SMPlayer-seed via `systemd.tmpfiles` `C` in `hosts/mpenzi/apps.nix` (`[performance] hwdec=auto`). Overzetten naar het seed-mechanisme van het profiel en opnemen in `herstel-app maaike smplayer`; de tmpfiles-regels dan weghalen.

- Gouden Nextcloud-config staat al in `home/profiles/maaike/defaults/nextcloud.cfg` (vastgelegd van mpenzi, client 34.0.4). Gebruik die als seed i.p.v. zelf een cfg te schrijven.

- Gouden ZapZap-config staat in `home/profiles/maaike/defaults/ZapZap.conf` (→ `~/.config/ZapZap/ZapZap.conf`). Signal: GEEN seed (config.json bevat encryptedKey); `herstel-app maaike signal` = alleen uitleg/opnieuw koppelen.


## Summary of Changes

- `home/profiles/maaike/seeds.nix`: lijst (nextcloud, bitwarden, zapzap, smplayer) + script `seed-apps [--force]`; HM-activatie seedt alleen ontbrekende bestanden (kopie, 0600, geen symlink).
- Bitwarden-seed: minimale `data.json` (server vw.toorren.net, stateVersion 83, formaat uit app.asar 2026.8.0).
- `herstel-app <gebruiker> <app|all>`: pkill -u, `*.bak-<datum>`, seed als de gebruiker (runuser); spotify = agenix-symlink terug; signal = uitleg.
- SMPlayer-tmpfiles uit `hosts/mpenzi/apps.nix` naar de seed.
