# Tasks

## 1. Gedeelde commando-router

- [x] 1.1 In `scripts.yaml` een `script.command_router` maken met velden `command`, `args`, `reply`;
  het choose-blok uit de Telegram-handler erin verhuizen, met `action: "{{ reply }}"` als
  antwoordkanaal. Verifieer dat alle commando's aanwezig zijn: `/start /adventkerst /hitte /wto
  /werk /wazewtotooffice /afvalack /aircraft` + de default (onbekend commando).
- [x] 1.2 De dubbele `/adventkerst`-branch verwijderen (één branch overhouden). Verifieer dat
  `/adventkerst` precies één keer in de router voorkomt.
- [x] 1.3 `hass --script check_config` draaien; verifieer dat het script zonder fout laadt.

## 2. Telegram-handler afslanken

- [x] 2.1 Automation `202411192011005` omzetten: trigger `telegram_command` blijft, acties worden
  één aanroep van `script.command_router` met `command=trigger.event.data.command`,
  `args=trigger.event.data.args`, `reply='notify.wouter'`.
- [x] 2.2 Na herstart live testen: elk commando via Telegram werkt nog onveranderd (toggle +
  antwoord via `notify.wouter`), inclusief `/aircraft 30` en `/aircraft status`.

## 3. Signal ontvangen (rest_command + whitelist)

- [x] 3.1 In `configuration.yaml` een `rest_command.signal_receive` toevoegen:
  `GET http://127.0.0.1:8088/v1/receive/<bot>?timeout=10&ignore_attachments=true`, met
  `response_variable`. Verifieer via `check_config` + een handmatige aanroep dat de response de
  msgs-array teruggeeft.
- [x] 3.2 Een afzender-whitelist vastleggen (minimaal `+31636201589`) op een plek die de
  poll-automation kan lezen (bv. een lijst-variabele of `input_text`/`!secret`). Verifieer dat de
  whitelist uitleesbaar is in een template.

## 4. Signal poll-automation

- [x] 4.1 Nieuwe automation: trigger `time_pattern` ~elke 30s, `mode: single`, `max_exceeded:
  silent`. Roept `signal_receive` aan en itereert de msgs met `repeat.for_each`.
- [x] 4.2 Filter per bericht: alleen verwerken als `envelope.dataMessage.message` bestaat én begint
  met `/` én `envelope.source` op de whitelist staat. Verifieer dat typing-/receipt-envelopes en
  niet-commando-tekst worden overgeslagen.
- [x] 4.3 De rauwe tekst splitsen: `command` = eerste token, `args` = rest; dan
  `script.command_router(command, args, reply='notify.signal_maria')`. Verifieer de split op
  `"/aircraft 30"` → `/aircraft` + `[30]`.
- [x] 4.4 `hass --script check_config` → herstart `docker-homeassistant.service`; verifieer dat HA
  schoon opkomt en de nieuwe automation `on` staat.

## 5. Integratie-verificatie (live)

- [x] 5.1 Stuur een `/commando` (bv. `/wto`) via Signal vanaf het gewhiteliste nummer; verifieer dat
  de actie uitgevoerd wordt én het antwoord via Signal (`notify.signal_maria`) terugkomt, binnen
  ~1 pollcyclus.
- [x] 5.2 Stuur `/aircraft 30` via Signal; verifieer timer + helper + Signal-bevestiging (args
  correct geparsed).
- [x] 5.3 Negatieftest: een bericht van een niet-gewhiteliste afzender én een typ-indicator leiden
  tot géén actie en géén antwoord.
- [x] 5.4 Regressie: Telegram-kant nog volledig werkend (herhaal 2.2 kort).
- [x] 5.5 CHANGELOG bijwerken onder `## NEXT VERSION` met een gebruikersgerichte beschrijving.

## Workflow follow-up

- Overstap naar `MODE=json-rpc` met realtime websocket-receive (modules/signal-cli.nix) — alleen als
  de ~30-45s latentie hindert; apart af te wegen.
- Nieuwe commando's toevoegen gebeurt voortaan één keer in `script.command_router`.
- Change archiveren nadat alles live geverifieerd is.
