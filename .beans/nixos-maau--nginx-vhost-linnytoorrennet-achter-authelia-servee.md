---
# nixos-maau
title: nginx vhost linny.toorren.net achter Authelia (serveert live static)
status: completed
type: feature
priority: normal
created_at: 2026-09-03T05:21:30Z
updated_at: 2026-09-03T06:21:03Z
parent: nixos-anvf
blocked_by:
    - nixos-bet5
    - nixos-0b9m
---

Nginx vhost `linny.toorren.net` serveert de **live** static-map achter **Authelia**.

## Todo
- [ ] `services.nginx.virtualHosts."linny.toorren.net"`: `forceSSL`, `useACMEHost = "toorren.net"`
- [ ] `root` = de live static-dir; `try_files` voor de Pagefind-assets/SPA-routes
- [ ] Authelia forward-auth (patroon uit `cockpit.nix`/`status-page.nix`)
- [ ] nginx-user leesrechten op de build-output (owner/group of ACL)

## Notitie
Privé klantnotities → NIET publiek; altijd achter Authelia.



## Summary of Changes
nginx vhost linny.toorren.net (forceSSL, useACMEHost toorren.net), root = live-symlink, Authelia forward-auth. nginx in torrlinny-groep + werkmap 0750 voor leesrechten. Geverifieerd: 302 -> Authelia, nginx leest de site.
