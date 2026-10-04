---
# nixos-rvwt
title: error_page 502/503/504 -> @sleeping (scoped op nxc-vhost)
status: completed
type: task
priority: high
created_at: 2026-10-04T20:58:22Z
updated_at: 2026-10-04T21:08:42Z
parent: nixos-pudl
---

In `modules/nextcloud-proxy.nix`:
- In location "/": `error_page 502 503 504 = @sleeping;`
- Nieuwe named location `@sleeping`: `internal;`, `root /var/www/nxc;`, serveer de
  static slaappagina.

Let op: scoped op deze vhost, NIET in `modules/nginx.nix` commonHttpConfig -- anders
krijgen Paperless/Grafana e.d. bij een echte 502 ook de "Nextcloud slaapt"-pagina.
`proxy_intercept_errors` niet toevoegen: de connect-fout wordt door nginx zelf
gegenereerd en door error_page afgevangen.



## Summary of Changes
`modules/nextcloud-proxy.nix`: `error_page 502 503 504 =503 @sleeping;` + interne `@sleeping`-location (root /var/www/nxc, Retry-After 1800, Cache-Control no-store, try_files /sleeping.html). Gescoped op alleen de nxc-vhost (geverifieerd: 1x error_page, geen andere vhost). Functioneel getest met wegwerp-nginx tegen dode upstream -> HTTP 503 + slaappagina + headers.
