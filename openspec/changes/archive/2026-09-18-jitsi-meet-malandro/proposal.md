## Status: GEANNULEERD (2026-09-18)

**Deze change wordt niet uitgevoerd en niet afgerond — hij is geannuleerd.**

**Reden:** malandro heeft onvoldoende resources om Jitsi Meet zelf te hosten. Prosody, JiCoFo en
de Videobridge draaien permanent naast alle bestaande diensten op die host, en de videobridge
vraagt bij elke conferentie CPU en bandbreedte die er niet structureel is. De gebruiker kiest
ervoor Jitsi niet zelf te hosten; `jitsi-meet-electron` blijft als *client* op lobos staan
(`hosts/lobos/programs.nix`) — alleen de server-kant vervalt.

**Stand van de repo op moment van annuleren (geverifieerd):**

- `modules/jitsi.nix` bestaat **niet**.
- `hosts/malandro/configuration.nix` bevat **geen enkele** jitsi-verwijzing.
- De enige jitsi-referentie in de hele config is de desktop-app op lobos.

De afgevinkte taken 1.1 t/m 3.1 staan dus **niet** in de huidige repo. Historisch zijn ze op
2026-07-17 wél geland (commit `01a94b4`, samen met deze change), maar op 2026-08-28 volledig
teruggedraaid in commit `11dd6c0` *"Verwijder Jitsi Meet server-module; behoud alleen desktop-app
op lobos"*. Ook de bijbehorende `jitsi-*-password`-secrets zijn toen uit `secrets/secrets.nix`
verwijderd. Taken 4.x en 5.x (DNS, deploy, prosodyctl-gebruiker) zijn nooit gedaan.
Er is dus **niets terug te draaien**; annuleren is een papieren handeling.

**Op malandro zelf (geverifieerd 2026-09-18):** geen jitsi/prosody/jicofo-units, geen containers,
geen luisterende poorten (UDP 10000, TCP 5222/5347), geen nginx-vhost voor `meet.toorren.net`.
Wel nog **restanten van de oude deploy**: `/var/lib/jitsi-meet/` (secrets + zelfondertekend cert,
17-07-2026) en `/var/lib/prosody/` met de hosts `meet.toorren.net`, `auth.meet.toorren.net` en
`recorder.meet.toorren.net`. Die zijn bewust **niet** opgeruimd — dat is een aparte beslissing.

**Delta-specs zijn bewust NIET naar de hoofdspecs gesynct.** `specs/jitsi-meet/spec.md` beschrijft
een capability die niet bestaat en niet gebouwd gaat worden; die in `openspec/specs/` opnemen zou
een niet-bestaande werkelijkheid vastleggen. Er is dus géén `openspec archive` en géén sync
gedraaid — de change is handmatig naar `openspec/changes/archive/` verplaatst.

---

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
