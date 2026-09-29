## 1. Configuratie

- [ ] 1.1 Lifespan-profiel `connector` onder `identity_providers.oidc.lifespans.custom`:
      `access_token: "1h"` (expliciet, zie design 2) en `refresh_token: "30d"`
- [ ] 1.2 `claude-connector` verwijst met `lifespan = "connector"` naar dat profiel
- [ ] 1.3 `consent_mode` van `explicit` naar `pre-configured` + `pre_configured_consent_duration`
- [ ] 1.4 Het commentaar bij die client corrigeren: daar staat nu dat `explicit` een EIS is van
      Authelia. Dat gold alleen bij `authelia.bearer.authz` en is onjuist geworden

## 2. Valideren vóór de switch

- [ ] 2.1 `authelia validate-config` op een minimale configuratie met de gewijzigde client, in
      isolatie op malandro — een ongeldige client laat Authelia niet starten
- [ ] 2.2 `nix eval` van de malandro-config slaagt

## 3. Toets

- [ ] 3.1 `modules/authelia_test.py` in de stijl van `modules/linny-mcp_test.py`
      (`nix eval --apply` op de opgebouwde config)
- [ ] 3.2 `claude-connector` heeft `consent_mode = "pre-configured"` met een duur
- [ ] 3.3 `claude-connector` verwijst naar het lifespan-profiel
- [ ] 3.4 Het profiel heeft `access_token = "1h"` — borgt dat alleen de refresh-token verlengd is
- [ ] 3.5 `wallos` gebruikt het profiel NIET en houdt zijn eigen consent-instellingen
- [ ] 3.6 De sessie-cookie is ongewijzigd (`inactivity`, `expiration`)
- [ ] 3.7 Het `legacy`-authz-endpoint bestaat nog naast `mcp` — dat verdween eerder en legde alle
      vhosts plat

## 4. Uitrollen en meten

- [ ] 4.1 Nulpunt vastleggen: aantal autorisatiecodes voor `claude-connector` en het aantal
      sessiesleutels in redis
- [ ] 4.2 Switch op malandro; `authelia-main` blijft actief
- [ ] 4.3 Regressie: `auth`, `linny`, `status`, `grafana`, `homeassistant` reageren zoals voorheen
- [ ] 4.4 Regressie: Wallos-login doorlopen — die client deelt de provider
- [ ] 4.5 Connector opnieuw koppelen; de eerste ronde toont nog een toestemmingsscherm
- [ ] 4.6 **Na enkele dagen hertellen.** Bij dagelijks gebruik hoort het aantal autorisatiecodes
      niet te stijgen. Stijgt het wel, dan klopt de aanname over rotatie niet en hoort dat in
      `design.md` — niet weggepoetst

## 5. Documentatie

- [ ] 5.1 `docs/linny-mcp.md`: de drie klokken (sessie-cookie, access-token, refresh-token), welke
      waarvan is, en waarom de sessie-cookie er bewust buiten blijft
- [ ] 5.2 Vastleggen dat "onthoud mij" de juiste hefboom is voor de browsersessie
- [ ] 5.3 `CHANGELOG.md` onder `## NEXT VERSION`
