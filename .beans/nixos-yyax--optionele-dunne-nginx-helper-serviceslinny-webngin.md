---
# nixos-yyax
title: 'Optionele dunne nginx-helper: services.linny-web.nginx { enable, virtualHost, useACMEHost }'
status: completed
type: task
priority: normal
created_at: 2026-09-04T08:32:49Z
updated_at: 2026-09-04T11:37:58Z
parent: nixos-dhh8
---

Als nginx.enable: zet services.nginx.virtualHosts.<virtualHost>.root = webRoot, forceSSL + useACMEHost, locations. Apache/caddy-gebruikers negeren dit en wiren zelf via config.services.linny-web.webRoot. Kern blijft webserver-agnostisch.
