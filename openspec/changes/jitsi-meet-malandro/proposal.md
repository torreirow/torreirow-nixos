## Why

Zelfgehoste videovergadering via Jitsi Meet op malandro, zodat externe deelnemers kunnen joinen via een eigen domein zonder afhankelijkheid van commerciële diensten zoals Zoom of Teams. Malandro is de logische plek omdat alle publieke services daar draaien met bestaande nginx- en ACME-infrastructuur.

## What Changes

- Verwijder de lege stub `modules/jitsi.nix`
- Maak nieuwe `modules/jitsi.nix` aan met volledige `services.jitsi-meet` configuratie
- Importeer de module in `hosts/malandro/configuration.nix`
- Gebruik bestaand `*.toorren.net` wildcard cert via `useACMEHost = "toorren.net"`
- Geen Authelia-integratie (incompatibel met WebRTC/XMPP verbindingen)
- SecureDomain ingeschakeld: alleen geauthenticeerde gebruikers kunnen rooms aanmaken, gasten joinen vrij via link
- Firewall open voor UDP 10000-20000 (Jitsi Videobridge media)

## Capabilities

### New Capabilities

- `jitsi-meet`: Zelfgehoste videovergadering op `meet.toorren.net` via NixOS `services.jitsi-meet`, met Prosody (XMPP), JiCoFo, Jitsi Videobridge en nginx frontend

### Modified Capabilities

## Impact

- **Nieuw bestand**: `modules/jitsi.nix`
- **Gewijzigd**: `hosts/malandro/configuration.nix` (module import toegevoegd)
- **Verwijderd**: huidige lege stub `modules/jitsi.nix` (6 regels, placeholder)
- **Systeemdiensten nieuw**: `prosody`, `jicofo`, `jitsi-videobridge2`
- **Firewall**: UDP 10000-20000 open op malandro
- **DNS**: A-record `meet.toorren.net` → malandro IP handmatig toevoegen in Route53 (buiten NixOS config)
- **Post-deploy stap**: `sudo prosodyctl adduser wouter@meet.toorren.net` voor SecureDomain gebruiker
