---
# nixos-bg0o
title: 'ai-blocklist: link-preview-bots (facebookexternalhit) per site toestaan'
status: completed
type: epic
priority: normal
tags:
    - ai-blocklist
    - cckafe
created_at: 2026-11-09T19:17:50Z
updated_at: 2026-11-09T20:16:05Z
---

## Probleem

`modules/ai-blocklist` geeft `facebookexternalhit` een 403 (staat in de
ai.robots.txt-lijst omdat Meta die UA ook voor AI-doeleinden gebruikt). Gevolg:
gedeelde links naar cckafe.com tonen **geen Open Graph-preview** in Facebook,
Messenger en Instagram.

Gemeten op 2026-11-09 (`curl -A <ua> https://cckafe.com/`):

| User-agent                          | Status |
|-------------------------------------|--------|
| facebookexternalhit/1.1             | 403    |
| WhatsApp, LinkedInBot, Slackbot     | 200    |
| Twitterbot, TelegramBot, Googlebot  | 200    |

## Aanpak

- Nieuwe optie per site: `services.aiBlocklist.sites.<vhost>.allowAgents`
  (lijst user-agents die NIET in de 403-map en NIET in de Disallow-groep komen).
- `update-ai-blocklist.py`: allowAgents uitfilteren bij `render_robots`; voor de
  nginx-map een per-vhost uitzondering (bv. tweede map `$ai_bot_allowed` of
  `if`-volgorde) zodat de globale map gedeeld blijft.
- `hosts/malandro/configuration.nix`: `"cckafe.com".allowAgents = [ "facebookexternalhit" ];`

## Klaar wanneer

- [x] `curl -A "facebookexternalhit/1.1" https://cckafe.com/` geeft 200
- [x] `https://cckafe.com/robots.txt` bevat geen Disallow voor facebookexternalhit
- [x] Andere sites houden de 403 voor facebookexternalhit
- [x] Facebook Sharing Debugger toont de OG-afbeelding van cckafe.com

## Context

Hangt samen met de cckafe-website-refactor (OG-afbeelding + SEO in change
`design-system-foundation`). Geen blokkade daarvoor: de site werkt zonder.
