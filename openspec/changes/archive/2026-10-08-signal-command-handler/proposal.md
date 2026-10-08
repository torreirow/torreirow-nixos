# Proposal

## Why

De Home Assistant-commando's (`/wto`, `/werk`, `/hitte`, `/aircraft`, …) werken nu alléén via
Telegram, omdat Telegram's HA-integratie tweerichting is en een `telegram_command`-event levert.
Signal in HA is enkel verzend (`notify.signal_maria` → de signal-cli-container), er is geen
inkomend event. Ik wil dezelfde commando's ook via Signal kunnen geven. Live op malandro
(2026-10-08) is bevestigd dat de signal-cli-container inkomende berichten teruggeeft via
`GET /v1/receive` (een `/aircraft 30` kwam binnen als `envelope.dataMessage.message`), dus HA kan
dit volledig zelf afhandelen door die endpoint te pollen — geen externe dienst, geen nix-wijziging.

## What Changes

- **Gedeelde commando-router**: het choose-blok uit de Telegram-handler wordt een herbruikbaar
  `script.command_router(command, args, reply)` dat de actie uitvoert en antwoordt via de als
  variabele doorgegeven notify-service (`action: "{{ reply }}"`). De dubbele `/adventkerst`-branch
  wordt daarbij opgeruimd. Alle bestaande commando's blijven werken (parity).
- **Telegram-handler afgeslankt**: triggert nog op `telegram_command` en roept de router aan met
  `reply='notify.wouter'`.
- **Signal ontvangen (nieuw)**: een `rest_command.signal_receive` pollt
  `GET http://127.0.0.1:8088/v1/receive/<bot>` en een poll-automation (time_pattern) zet elk
  inkomend `/commando` van een gewhiteliste afzender om in een router-aanroep met
  `reply='notify.signal_maria'`.
- **Ruis- en toegangsfilter**: envelopes zonder `dataMessage.message` (typing-/receipt-indicatoren)
  en niet-gewhiteliste afzenders worden genegeerd.

## Capabilities

### New Capabilities
- `chat-command-router`: het aannemen van gebruikerscommando's uit chatkanalen (Telegram én Signal)
  en die via één gedeelde router op dezelfde HA-acties afbeelden, met antwoord op het kanaal van
  herkomst, afzender-autorisatie en kanaal-specifieke inname (Telegram-event vs. Signal-poll).

### Modified Capabilities
<!-- Geen bestaande spec onder openspec/specs/ dekt chat-commando's; dit is net-nieuw. -->

## Impact

- **Betrokken (HA-runtime, `/var/lib/homeassistant`)**:
  - `scripts.yaml` — nieuw `script.command_router`.
  - `automations.yaml` — Telegram-handler (id `202411192011005`) afslanken + nieuwe Signal-poll-automation.
  - `configuration.yaml` — `rest_command.signal_receive` + afzender-whitelist.
  - Backups `*.bak-claude-*`; werkwijze edit → `hass --script check_config` → herstart
    `docker-homeassistant.service`.
- **Geen** wijziging aan de nix-repo: de signal-cli-container (`modules/signal-cli.nix`, `MODE=native`)
  blijft ongemoeid; replies hergebruiken het bestaande `notify.signal_maria`.
- **Buiten scope**: overstap naar `MODE=json-rpc` (realtime websocket-receive, lagere latentie, meer
  moving parts); Signal command-menu/inline-knoppen; nieuwe commando's toevoegen.
- **Trade-off**: pollen geeft ~30-45s latentie (vs. instant bij Telegram); acceptabel voor
  toggles/status. Bijvangst: regelmatig ontvangen houdt de Signal-sessie gezond.
