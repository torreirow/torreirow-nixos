## ADDED Requirements

### Requirement: Jitsi Meet bereikbaar via HTTPS op meet.toorren.net
Het systeem SHALL Jitsi Meet serveren via `https://meet.toorren.net` met een geldig TLS-certificaat (wildcard `*.toorren.net`).

#### Scenario: Gebruiker opent Jitsi Meet in browser
- **WHEN** een gebruiker `https://meet.toorren.net` opent in een browser
- **THEN** laadt de Jitsi Meet webinterface met HTTPS zonder certificaatwaarschuwing

### Requirement: SecureDomain — alleen geauthenticeerde gebruiker maakt rooms aan
Het systeem SHALL vereisen dat een gebruiker inlogt met een Prosody-account om een nieuwe room aan te maken. Gasten die joinen via een bestaande link SHALL geen login nodig hebben.

#### Scenario: Geauthenticeerde gebruiker maakt een room aan
- **WHEN** een gebruiker `https://meet.toorren.net/mijnroom` opent en nog geen room bestaat
- **THEN** vraagt Jitsi om een gebruikersnaam en wachtwoord (Prosody XMPP login)

#### Scenario: Gast joint een bestaande room via link
- **WHEN** een gast een directe room-URL opent terwijl de room al actief is
- **THEN** kan de gast deelnemen zonder in te loggen

### Requirement: Prosody draait in lockdown-modus
Prosody SHALL uitsluitend op localhost luisteren en SHALL geen externe XMPP-federatie (S2S) ondersteunen.

#### Scenario: Prosody luistert niet op externe interfaces
- **WHEN** Prosody actief is
- **THEN** zijn de XMPP-poorten (5222, 5269) niet bereikbaar van buiten localhost

### Requirement: Jitsi Videobridge media via UDP
Het systeem SHALL UDP-verkeer op poorten 10000-20000 accepteren voor WebRTC-mediaforbindingen van Jitsi Videobridge.

#### Scenario: Externe deelnemer verbindt media-stream
- **WHEN** een externe deelnemer deelneemt aan een meeting
- **THEN** wordt de audio/video-verbinding opgezet via UDP poort in range 10000-20000

### Requirement: Jitsi-configuratie als NixOS-module
De Jitsi Meet-installatie SHALL volledig declaratief geconfigureerd zijn via `modules/jitsi.nix` en geïmporteerd in `hosts/malandro/configuration.nix`.

#### Scenario: NixOS rebuild activeert alle Jitsi-services
- **WHEN** `sudo nixos-rebuild switch --flake .#malandro` wordt uitgevoerd met de jitsi module geïmporteerd
- **THEN** starten de services `prosody`, `jicofo` en `jitsi-videobridge2` automatisch
