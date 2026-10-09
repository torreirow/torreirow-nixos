---
# nixos-1pnf
title: 'Signal-commando''s: dezelfde HA-commando''s via Signal als via Telegram'
status: completed
type: epic
priority: normal
created_at: 2026-10-08T21:15:33Z
updated_at: 2026-10-08T21:39:35Z
---

Geef dezelfde Home Assistant-commando's die nu alleen via Telegram werken, ook via Signal.

OpenSpec change: signal-command-handler
(openspec/changes/signal-command-handler/)

Kern: een gedeelde `script.command_router` (choose-blok uit de Telegram-handler) die beide kanalen
bedient; Signal-inname via polling van de signal-cli REST-API `GET /v1/receive` (HA krijgt geen
event zoals Telegram); replies via het bestaande `notify.signal_maria`. Volledig HA-runtime, geen
nix-wijziging. Trade-off: ~30-45s latentie (native-mode polling).

Live geverifieerd (2026-10-08): inkomend `/aircraft 30` opgevangen; typing/receipt-ruis moet
gefilterd; command/args niet voorgesplitst door Signal.
