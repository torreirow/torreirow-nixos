## 1. Configuratie

- [x] 1.1 Lifespan-profiel `connector` onder `identity_providers.oidc.lifespans.custom`:
      `access_token: "1h"` (expliciet, zie design 2) en `refresh_token: "30d"`
- [x] 1.2 `claude-connector` verwijst met `lifespan = "connector"` naar dat profiel
- [x] 1.3 `consent_mode` van `explicit` naar `pre-configured` + `pre_configured_consent_duration`
- [x] 1.4 Het commentaar bij die client corrigeren: daar staat nu dat `explicit` een EIS is van
      Authelia. Dat gold alleen bij `authelia.bearer.authz` en is onjuist geworden

## 2. Valideren vóór de switch

- [x] 2.1 `authelia validate-config` op een minimale configuratie met de gewijzigde client, in
      isolatie op malandro — een ongeldige client laat Authelia niet starten
- [x] 2.2 `nix eval` van de malandro-config slaagt

## 3. Toets

- [x] 3.1 `modules/authelia_test.py` in de stijl van `modules/linny-mcp_test.py`
      (`nix eval --apply` op de opgebouwde config)
- [x] 3.2 `claude-connector` heeft `consent_mode = "pre-configured"` met een duur
- [x] 3.3 `claude-connector` verwijst naar het lifespan-profiel
- [x] 3.4 Het profiel heeft `access_token = "1h"` — borgt dat alleen de refresh-token verlengd is
- [x] 3.5 `wallos` gebruikt het profiel NIET en houdt zijn eigen consent-instellingen
- [x] 3.6 De sessie-cookie is ongewijzigd (`inactivity`, `expiration`)
- [x] 3.7 Het `legacy`-authz-endpoint bestaat nog naast `mcp` — dat verdween eerder en legde alle
      vhosts plat

## 4. Uitrollen en meten

- [x] 4.1 Nulpunt 2026-09-29 22:08:48 — 7 autorisatiecodes, 9 toestemmingen, 1324 sessies in redis
- [x] 4.2 Switch op malandro; `authelia-main` blijft actief
- [x] 4.3 Regressie gemeten: auth 200, linny 302, status 302, grafana 302, homeassistant 200,
      subscriptions 302 — alle zoals voorheen
- [x] 4.4 Wallos-autorisatie geeft 303 naar de inlogpagina (geen fout), en erft het
      lifespan-profiel niet. De login zélf doorlopen is handwerk voor de eigenaar
- [ ] 4.5 Connector opnieuw koppelen; de eerste ronde toont nog een toestemmingsscherm
- [ ] 4.6 **Na enkele dagen hertellen.** Bij dagelijks gebruik hoort het aantal autorisatiecodes
      niet te stijgen. Stijgt het wel, dan klopt de aanname over rotatie niet en hoort dat in
      `design.md` — niet weggepoetst

## 5. Documentatie

- [x] 5.1 `docs/linny-mcp.md`: de drie klokken (sessie-cookie, access-token, refresh-token), welke
      waarvan is, en waarom de sessie-cookie er bewust buiten blijft
- [x] 5.2 Vastleggen dat "onthoud mij" de juiste hefboom is voor de browsersessie
- [x] 5.3 `CHANGELOG.md` onder `## NEXT VERSION`
