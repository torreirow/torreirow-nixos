## 1. Opruimen bestaande stub

- [x] 1.1 Verwijder de huidige lege stub `modules/jitsi.nix`

## 2. Module aanmaken

- [x] 2.1 Maak `modules/jitsi.nix` aan met `services.jitsi-meet` configuratie (hostName, secureDomain, prosody.lockdown)
- [x] 2.2 Voeg nginx vhost override toe in de module: `enableACME = false`, `useACMEHost = "toorren.net"`, `forceSSL = true`
- [x] 2.3 Voeg firewall-regels toe in de module: UDP 10000-20000 voor Jitsi Videobridge

## 3. Malandro koppelen

- [x] 3.1 Voeg `../../modules/jitsi.nix` toe aan de imports in `hosts/malandro/configuration.nix`

## 4. DNS en deploy

- [ ] 4.1 Voeg A-record toe in Route53: `meet.toorren.net` → malandro IP (handmatig via AWS console of CLI)
- [ ] 4.2 Deploy naar malandro: `sudo nixos-rebuild switch --flake .#malandro`
- [ ] 4.3 Verifieer dat services draaien: `systemctl status prosody jicofo jitsi-videobridge2`

## 5. Post-deploy configuratie

- [ ] 5.1 Maak Prosody-gebruiker aan voor SecureDomain: `sudo prosodyctl adduser wouter@meet.toorren.net`
- [ ] 5.2 Test room aanmaken op `https://meet.toorren.net` (login vereist)
- [ ] 5.3 Test gast joinen via directe room-URL (geen login vereist)
