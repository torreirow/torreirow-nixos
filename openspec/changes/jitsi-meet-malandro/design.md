## Context

Malandro is de centrale server met nginx, ACME (wildcard `*.toorren.net` via Route53/DNS-01) en Authelia. NixOS biedt een volledige `services.jitsi-meet` module die Prosody, JiCoFo, Jitsi Videobridge en nginx-integratie automatisch configureert. De bestaande stub `modules/jitsi.nix` is een lege placeholder (6 regels, nooit ingeschakeld).

Hardware: Celeron J3455 @ 1.50GHz, 4 cores, 7.6 GiB RAM (4.5 GiB beschikbaar). Jitsi Videobridge is een SFU — het transcodeert niet, alleen packet forwarding. Geschikt voor meetings tot ~10 deelnemers.

## Goals / Non-Goals

**Goals:**
- Jitsi Meet bereikbaar via `meet.toorren.net` met HTTPS
- SecureDomain: geauthenticeerde gebruiker maakt rooms aan, gasten joinen zonder login
- Prosody volledig intern (lockdown mode, geen externe XMPP federatie)
- Videobridge media via UDP 10000-20000

**Non-Goals:**
- Authelia SSO-integratie (incompatibel met WebRTC/XMPP)
- Jibri (opnemen) of Jigasi (telefoniebrug) — niet nodig
- Jitsi op lobos (desktop) draaien
- Meerdere videobridge-instanties

## Decisions

### 1. ACME: bestaand wildcard cert hergebruiken

`services.jitsi-meet` zet `enableACME = mkDefault true` op de nginx vhost. Omdat het `mkDefault` is, wordt dit overschreven door een expliciete instelling in de module:

```nix
services.nginx.virtualHosts."meet.toorren.net" = {
  enableACME = false;
  useACMEHost = "toorren.net";
  forceSSL = true;
};
```

**Alternatief overwogen**: Aparte ACME cert voor `meet.toorren.net`. Verworpen — wildcard dekt het al, extra cert is onnodige complexiteit.

### 2. Authelia overslaan

Authelia werkt via `auth_request` op nginx-level. Jitsi's BOSH (`/http-bind`) en WebSocket (`/xmpp-websocket`) endpoints worden continu aangesproken door de client — Authelia zou deze blokkeren. Jitsi heeft eigen authenticatie via SecureDomain.

**Alternatief overwogen**: Authelia alleen op de root (`/`) en uitzonderingen voor `/http-bind` en `/xmpp-websocket`. Te complex en foutgevoelig. SecureDomain is de juiste laag voor toegangscontrole.

### 3. SecureDomain voor room-aanmaken

`services.jitsi-meet.secureDomain.enable = true` configureert Prosody zodat room-aanmaken een XMPP-login vereist. Gasten die via een link joinen hoeven niet in te loggen.

Post-deploy handmatige stap vereist:
```bash
sudo prosodyctl adduser wouter@meet.toorren.net
```

**Alternatief overwogen**: Volledig open (iedereen maakt rooms aan). Verworpen — rooms zouden dan ook door bots of onbekenden aangemaakt kunnen worden.

### 4. Prosody lockdown

`services.jitsi-meet.prosody.lockdown = true` schakelt S2S (server-to-server XMPP federatie) uit en beperkt Prosody tot localhost-interfaces. Niet nodig als publieke XMPP-server.

### 5. Module als standalone `modules/jitsi.nix`

Consistent met alle andere services op malandro (vikunja.nix, vaultwarden.nix, etc.). De module wordt geïmporteerd in `hosts/malandro/configuration.nix`.

## Risks / Trade-offs

**[Hardware begrenzing]** Celeron J3455 is een zwakke CPU. Bij grotere meetings (>10 deelnemers) kan de videobridge overbelast raken.
→ Mitigatie: Gebruik voor kleine meetings. Monitor CPU bij eerste gebruik.

**[UDP firewall]** UDP 10000-20000 moet open zijn in zowel NixOS firewall als router/NAT. Als malandro achter NAT zit zonder port forwarding, werkt media niet voor externe deelnemers.
→ Mitigatie: Verifieer dat malandro direct publiek bereikbaar is (VPS of juiste port forwarding).

**[Prosody zelfondertekend cert]** Prosody genereert een zelfondertekend certificaat voor interne XMPP communicatie. Dit is normaal en geen probleem omdat het alleen intern gebruikt wordt.
→ Geen actie vereist.

**[Post-deploy handmatige stap]** SecureDomain-gebruiker aanmaken via `prosodyctl` kan niet via Nix declaratief. Als dit vergeten wordt, werkt room-aanmaken niet.
→ Mitigatie: Documenteer in tasks.md als expliciete stap.

## Migration Plan

1. Verwijder stub `modules/jitsi.nix`
2. Maak nieuwe `modules/jitsi.nix` aan
3. Voeg import toe aan `hosts/malandro/configuration.nix`
4. Voeg A-record toe in Route53: `meet.toorren.net` → malandro IP
5. Deploy: `sudo nixos-rebuild switch --flake .#malandro`
6. Maak Prosody-gebruiker aan: `sudo prosodyctl adduser wouter@meet.toorren.net`
7. Test: open `https://meet.toorren.net`, maak een room aan

**Rollback**: Verwijder de import uit `configuration.nix` en rebuild. Alle Jitsi-services stoppen. Geen datamigratie nodig.

## Open Questions

~~Is malandro direct publiek bereikbaar op UDP 10000-20000?~~ **Opgelost**: Malandro is een NUC achter een router. UDP 10000-20000 wordt via port forwarding op de router opengezet (handmatige stap buiten NixOS config).
