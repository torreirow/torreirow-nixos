# Proposal

## Why

`modules/ai-blocklist` geeft `facebookexternalhit` een 403, omdat die user-agent in de
ai.robots.txt-lijst staat (Meta gebruikt hem ook voor AI-doeleinden). Daardoor tonen gedeelde
links naar cckafe.com geen Open Graph-preview in Facebook, Messenger en Instagram — juist de
kanalen waar cckafe gedeeld wordt. Gemeten op 2026-11-09: `facebookexternalhit/1.1` → 403,
WhatsApp/LinkedInBot/Slackbot/Twitterbot/TelegramBot/Googlebot → 200. De globale `ALLOWLIST`
in het script is geen oplossing: die zou de bot op álle sites toelaten.

## What Changes

- Nieuwe optie per site: `services.aiBlocklist.sites.<vhost>.allowAgents` (lijst botnamen,
  standaard leeg). Een bot in die lijst krijgt op díe site geen 403 en komt niet in de
  Disallow-groep van de gegenereerde `robots.txt`.
- De 403-controle van een site met `allowAgents` gebruikt een eigen nginx-variabele die afgeleid
  is van de gedeelde `$ai_bot`-map; sites zonder `allowAgents` blijven ongewijzigd op `$ai_bot`.
- `update-ai-blocklist.py` laat de `allowAgents` van een site weg bij het opbouwen van diens
  `robots.txt`.
- `hosts/malandro/configuration.nix`: `"cckafe.com".allowAgents = [ "facebookexternalhit" ];`
- `docs/ai-blocklist.md`: de valkuil over `facebookexternalhit` bijwerken naar de nieuwe optie.

## Capabilities

### New Capabilities

- `ai-crawler-blocklist`: het weren van AI-crawlers van de publieke statische sites op malandro
  (403 in nginx + aanvulling op `robots.txt`), inclusief per-site uitzonderingen. Er bestaat nog
  geen spec voor deze module; deze change legt alleen het nieuwe uitzonderingsgedrag vast.

### Modified Capabilities

(geen)

## Impact

- `modules/ai-blocklist/default.nix` (optie, extra map in `commonHttpConfig`, `if` per vhost,
  `allowAgents` in `SITES_JSON`)
- `modules/ai-blocklist/update-ai-blocklist.py` (`render_robots`)
- `hosts/malandro/configuration.nix` (cckafe.com)
- `docs/ai-blocklist.md`
- Alleen malandro; nginx-reload bij de switch. Andere sites houden exact hun huidige gedrag.
