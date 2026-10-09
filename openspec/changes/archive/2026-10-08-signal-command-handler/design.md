# Design

## Context

Zie proposal.md — Why. Alles leeft in HA-runtime (`/var/lib/homeassistant`): `automations.yaml`,
`scripts.yaml`, `configuration.yaml`. Uitrol = edit → `hass --script check_config` → herstart
`docker-homeassistant.service`.

Live geverifieerde feiten (malandro, 2026-10-08):
- Bestaande Telegram-handler: automation id `202411192011005`, trigger `telegram_command`, één
  choose-blok met `/start /adventkerst /hitte /wto /werk /wazewtotooffice /afvalack /aircraft`,
  antwoord via `notify.wouter`. Bevat een **dubbele** `/adventkerst`-branch.
- Signal verzenden: `notify.signal_maria` = platform `signal_messenger`, `url
  http://127.0.0.1:8088`, `number +31612652352` (bot), `recipient +31636201589`. Dezelfde container
  die de NFC-flow ("Vertrek naar huis", tag 155) gebruikt.
- Signal ontvangen: `GET /v1/receive/+31612652352` geeft een array terug. Het testbericht kwam als:
  `{"envelope":{"source":"+31636201589","dataMessage":{"message":"/aircraft 30"}}}`. De array bevat
  óók `typingMessage`- en `receiptMessage`-envelopes **zonder** `dataMessage.message`. Native-mode
  long-poll duurt ~10-22s per call.

## Goals / Non-Goals

**Goals:**
- Dezelfde commando's via Signal als via Telegram, zonder duplicatie van de commandologica.
- Volledig in HA; de signal-cli-container en de nix-repo blijven ongemoeid.

**Non-Goals:**
- `MODE=json-rpc`/websocket-realtime (blijft native + pollen).
- Nieuwe commando's; Signal command-menu/inline-knoppen.

## Decisions

**D1 — Gedeelde `script.command_router(command, args, reply)`.**
Het choose-blok verhuist uit de Telegram-handler naar een script met variabelen `command`, `args` en
`reply` (de notify-servicenaam). De router antwoordt via een **getemplate** notify-service
(`action: "{{ reply }}"`, in HA toegestaan). Zo bestaat elke commandodefinitie één keer en bedient
hij beide kanalen. Alternatief (choose-blok dupliceren naar een Signal-automation) verworpen: twee
kopieën lopen uit de pas — de bestaande dubbele `/adventkerst`-branch is daar het levende bewijs van;
die wordt bij de verhuizing opgeruimd.

**D2 — Telegram blijft op het integratie-event.**
De handler houdt zijn `telegram_command`-trigger en roept de router aan met
`reply='notify.wouter'`; `command`/`args` komen al gesplitst uit het event.

**D3 — Signal-inname via polling (`rest_command` + time_pattern).**
De Signal-integratie levert geen event, dus HA pollt zelf. `rest_command.signal_receive` doet
`GET …/v1/receive/<bot>?timeout=10&ignore_attachments=true` met `response_variable`. Een
poll-automation (time_pattern ~30s, `mode: single`, `max_exceeded: silent`) itereert de msgs. Het
antwoord hergebruikt `notify.signal_maria`; een aparte send-`rest_command` is overbodig.

**D4 — Filteren en zelf splitsen.**
De inname selecteert alleen envelopes met `envelope.dataMessage.message` die met `/` begint én
`envelope.source` op de whitelist. De rauwe tekst wordt met `split()` in commando (eerste token) en
args (rest) gesplitst — Signal levert, anders dan Telegram, geen voorgesplitste command/args.

**D5 — Native mode behouden.**
Pollen volstaat voor toggles/status; realtime is niet nodig. Gevolg: ~30-45s latentie en lichte
serialisatie tussen een gelijktijdige send (notify) en de long-poll receive op dezelfde container.
Bijvangst: regelmatig ontvangen houdt de Signal-sessie gezond (de container logt nu dat niemand
ontvangt).

## Risks / Trade-offs

- **Latentie ~30-45s** → acceptabel voor deze commando's; wie realtime wil, schakelt later naar
  json-rpc (buiten scope).
- **Destructieve receive** (poll verbruikt de berichten) → precies één consument mag pollen; de
  poll-automation is de enige. Meerdere berichten in één poll → de automation verwerkt de hele array
  (`repeat.for_each`).
- **Getemplate notify-service** moet door de draaiende HA-versie ondersteund worden → verifiëren bij
  `check_config` en een live Telegram- én Signal-test.
- **Afzender-spoofing** is op Signal praktisch uitgesloten (E2E, alleen het bot-account ontvangt),
  maar de whitelist blijft de harde grens.

## Migration Plan

1. `script.command_router` toevoegen (verhuisd choose-blok, dubbele `/adventkerst` weg).
2. Telegram-handler afslanken naar een router-aanroep.
3. `rest_command.signal_receive` + whitelist in `configuration.yaml`; Signal-poll-automation in
   `automations.yaml`.
4. `hass --script check_config` → herstart HA.
5. Verifiëren: Telegram-commando werkt onveranderd; een Signal-`/commando` van de whitelist voert uit
   en antwoordt via Signal; een niet-gewhiteliste afzender en een typ-indicator worden genegeerd.
6. Rollback: backups `*.bak-claude-*` terugzetten + HA herstarten.
