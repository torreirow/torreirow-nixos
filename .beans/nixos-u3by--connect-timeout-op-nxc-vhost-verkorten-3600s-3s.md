---
# nixos-u3by
title: Connect-timeout op nxc-vhost verkorten (3600s -> ~3s)
status: completed
type: task
priority: high
created_at: 2026-10-04T20:58:22Z
updated_at: 2026-10-04T21:08:42Z
parent: nixos-pudl
---

In `modules/nextcloud-proxy.nix`, location "/":
- `proxy_connect_timeout 3600s` -> `3s` (snel + deterministisch falen als host uit is).
- `proxy_send_timeout` / `proxy_read_timeout` op 3600s LATEN STAAN (grote uploads).

Rationale: connect-timeout is enkel de TCP-handshake; een gezonde LAN-host maakt die
in ms. De 3600s daar was vrijwel zeker meegekopieerd en is precies wat de "uit"-case
tot een uur laat hangen voordat de foutpagina verschijnt.



## Summary of Changes
`modules/nextcloud-proxy.nix`: `proxy_connect_timeout` 3600s -> 3s op de nxc-location. send/read-timeouts blijven 3600s (grote uploads). Geverifieerd in de gegenereerde nginx.conf.
