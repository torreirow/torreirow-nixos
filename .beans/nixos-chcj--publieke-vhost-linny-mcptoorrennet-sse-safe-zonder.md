---
# nixos-chcj
title: publieke vhost linny-mcp.toorren.net (SSE-safe, zonder Authelia)
status: todo
type: task
priority: normal
created_at: 2026-09-25T07:45:27Z
updated_at: 2026-09-25T07:45:40Z
parent: nixos-m0vn
blocked_by:
    - nixos-dqs2
    - nixos-ero6
---

Publieke HTTPS-vhost `linny-mcp.toorren.net` op malandro die naar de lokaal gebonden linny-mcp
proxyt. **Bewust zonder Authelia.**

## Waarom publiek en niet achter de VPN
Een custom connector op claude.ai wordt **server-side door Anthropic opgehaald**, niet door je
browser of je telefoon. Een endpoint dat alleen binnen wireguard bereikbaar is, is voor Claude
Online en Mobile onbereikbaar — ook al zit de telefoon zelf in de VPN. Online+mobile is een harde
eis, dus publiek + bearer-auth. Dit is ook waarom mipmip's `durer` publiek staat terwijl zijn
server op een privé-IP bindt.

## Waarom geen Authelia
Authelia is een redirect-gebaseerde browserflow. Een MCP-client stuurt alleen
`Authorization: Bearer` en volgt geen loginredirect. Deze vhost kan dus niet het
`autheliaAuthConfig`-patroon van `linny.toorren.net` gebruiken. De authenticatie zit in
linny-mcp zelf (story `bearer-tokens`).

## SSE-veilig proxyen
MCP's streamable-HTTP-transport mag niet gebufferd worden, heeft HTTP/1.1 nodig en een lange
read-timeout, anders stallen of breken langlopende `/mcp`-streams. mipmip's vhost als model:

    proxy_buffering off;
    proxy_request_buffering off;
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
    chunked_transfer_encoding off;

plus `proxyWebsockets = true` (dat forceert HTTP/1.1 + Upgrade/Connection).

## Todo
- [ ] DNS `linny-mcp.toorren.net` -> malandro
- [ ] `services.nginx.virtualHosts."linny-mcp.toorren.net"`: `forceSSL`, ACME/`useACMEHost`
      conform het patroon van de andere vhosts in deze repo
- [ ] `locations."/"` proxyPass naar het lokale linny-mcp-adres + de SSE-config hierboven
- [ ] **geen** `autheliaAuthConfig` / `autheliaVerifyLocation` op deze vhost
- [ ] fail2ban overwegen op herhaalde 401's (repo heeft al `modules/fail2ban.nix`) — afwegen, niet verplicht
- [ ] verifieer: cert geldig, `/healthz` 200 zonder auth
- [ ] verifieer: `/mcp` zonder token -> geweigerd
- [ ] verifieer: een langlopende stream wordt niet afgekapt
