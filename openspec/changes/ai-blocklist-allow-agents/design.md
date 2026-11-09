# Design

## Context

Zie proposal.md voor de aanleiding. Huidige werking (`modules/ai-blocklist/`):

- `update-ai-blocklist.py` schrijft dagelijks één gedeelde `map $http_user_agent $ai_bot` naar
  `/var/lib/ai-blocklist/ai-bots-map.conf`, geïncludeerd in `services.nginx.commonHttpConfig`.
  De lijst komt van ai.robots.txt en verandert buiten Nix om.
- Elke site krijgt `if ($ai_bot) { return 403; }` in `/` en de `extraLocations`; `= /robots.txt`
  wijst naar een per-vhost gegenereerd bestand.
- De globale `ALLOWLIST` in het script (nu alleen `Applebot`) geldt voor álle sites.

nginx kent geen `&&` in `if`, dus "AI-bot én niet toegestaan op deze vhost" moet in één variabele
uitkomen.

## Goals / Non-Goals

**Goals:**
- Per site botnamen kunnen vrijgeven, zonder de gedeelde, dagelijks ververste map te dupliceren.
- Sites zonder `allowAgents` krijgen byte-voor-byte dezelfde nginx-config als nu.

**Non-Goals:**
- Wildcards of regexen in `allowAgents`; alleen letterlijke botnamen.
- Bots vrijgeven die niet in de bronlijst staan (die worden al niet geblokkeerd; de optie is dan
  een no-op).
- De globale `ALLOWLIST` verplaatsen of vervangen.

## Decisions

### 1. Afgeleide map per site, statisch uit Nix

Voor elke site met niet-lege `allowAgents` zet de module in `commonHttpConfig` (na de include):

```nginx
map $http_user_agent $ai_bot_cckafe_com {
    default $ai_bot;
    "~*\b(?:facebookexternalhit)\b" 0;
}
```

en gebruikt die site `if ($ai_bot_cckafe_com) { return 403; }` in plaats van `$ai_bot`. De
variabelenaam is de vhost met alle niet-`[a-z0-9]`-tekens vervangen door `_`.

- nginx-maps accepteren een variabele als waarde en worden lui geëvalueerd, dus de afgeleide map
  volgt de dagelijks bijgewerkte `$ai_bot` zonder dat het script iets van uitzonderingen weet.
- `allowAgents` is statische configuratie, dus hoort in Nix en niet in een runtime-bestand; een
  fout in de map valt al bij `nixos-rebuild` (nginx-configcheck) op.

**Alternatieven:**
- *Het script schrijft per-vhost-maps* — kan, maar trekt statische config door de runtime-route
  en een fout komt pas bij de volgende service-run (met rollback) boven. Geen voordeel.
- *Map op `"$host:$http_user_agent"`* — één map, maar de regex moet host én bot combineren en
  `$host` volgt de `Host`-header (aliassen, `www.`); broos.
- *Bot in de globale `ALLOWLIST`* — opent alle sites; precies wat niet de bedoeling is.

### 2. robots.txt: filter in `render_robots`

`SITES_JSON` krijgt per site `allowAgents`. `render_robots` laat namen weg waarvan de kleine-
letterversie in de `allowAgents` van die site staat, vóór het bepalen van `missing`. Het script
logt een waarschuwing als een `allowAgents`-naam niet in de actuele botlijst voorkomt (typo of
uit de lijst verdwenen) — geen fout, want de uitvoer is dan gewoon correct.

### 3. Validatie van botnamen

`allowAgents` krijgt type `listOf (strMatching "[A-Za-z0-9._-]+")`. Daarmee hoeft er in Nix niets
geëscaped te worden voor de nginx-string, behalve `.` (via `lib.escapeRegex`), en kan een naam de
gequote map-regel niet breken.

## Risks / Trade-offs

- [Meta gebruikt `facebookexternalhit` ook voor AI-doeleinden; cckafe.com is daarmee voor die UA
  leesbaar] → Bewuste keuze voor de link-previews; alleen op cckafe.com, en `meta-externalagent`/
  `FacebookBot` blijven geblokkeerd.
- [Facebook cachet de 403 van eerdere scrapes] → Na deploy in de Sharing Debugger "Scrape Again"
  doen (taak 4).
- [Een vhost-naam die na het vervangen gelijk wordt aan een andere] → Praktisch uitgesloten bij de
  huidige zes sites; geen extra maatregel.

## Migration Plan

1. Module + script aanpassen, `allowAgents` voor cckafe.com zetten, malandro bouwen.
2. Op malandro `sudo nixos-rebuild switch` (gebruiker zelf), daarna
   `sudo systemctl start ai-blocklist.service` zodat `robots/cckafe.com.txt` direct herschreven
   wordt (anders pas bij de volgende timer-run).
3. Terugdraaien: `allowAgents` weghalen + switch + service opnieuw starten; zonder `allowAgents`
   is de config identiek aan de huidige.
