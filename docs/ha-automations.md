# Home Assistant automations (aircraft / geurhal / afzuiging)

HA-runtime-automations die buiten deze repo leven (/var/lib/homeassistant). Gedeelde lessen: timer 'restore: true' en de .storage stop-edit-start-werkwijze.

> Verplaatst uit CLAUDE.md (Huidige Status) om de sessie-context slank te houden.

## Aircraft-monitor uitzetten via /aircraft Telegram-commando

### Sessie 2026-08-26 - Aircraft-monitor tijdelijk uitzetten via /aircraft Telegram-commando - OPGELOST

**Wens:** De Aircraft-Monitor-melding tijdelijk kunnen uitzetten. `/aircraft 120` → zet een timer op
120 min en een helper aan; `/aircraft` zonder waarde → start de timer met zijn default-duur; als de
timer afloopt gaat de helper weer uit. De Signal-melding wordt onderdrukt zolang de helper aan staat.

**Opgezet (puur HA-runtime-config, leeft in `/var/lib/homeassistant`, niet in deze nixos-repo):**
- **Helper** `input_boolean.disable_aircraft_monitor` (naam "Aircraft monitor uit") — UI-helper in `.storage/input_boolean`.
- **Timer** `timer.aircraft_monitor` (naam "AircraftMonitorTimer", icon `mdi:airplane-off`, default
  duur **2:00:00**, **`restore: true`**) — UI-helper in `.storage/timer`. `restore: true` is hier
  cruciaal: met `false` springt de timer bij HA-herstart stil naar idle → `timer.finished` vuurt
  nooit → helper blijft eeuwig aan → monitor blijft eeuwig uit (zelfde les als afzuiging/geurhal).
- **Telegram Commando Handler** (`automations.yaml`, id `202411192011005`): drie nieuwe `choose`-branches
  (alle `command == '/aircraft'`, **volgorde-afhankelijk** — `choose` pakt de eerste match):
  - **`/aircraft status`** (args[0] == 'status', staat als eerste branch) → `notify.wouter` met een
    Jinja-template (`>-` folded scalar). Begint met de **meldingsstatus op basis van de helper**
    (`input_boolean.disable_aircraft_monitor` aan → "Meldingen: ONDERDRUKT", uit → "ACTIEF") — dat is
    de daadwerkelijke suppress-schakelaar — gevolgd door de timerstand: active → eindtijd + resterend,
    paused → resterend, idle → "Geen timer loopt" + default-duur. Moet vóór de min-branch staan,
    anders crasht `'status' | int`.
  - args aanwezig → `timer.start` met `duration: '{{ trigger.event.data.args[0] | int * 60 }}'` (min→sec),
    helper aan, bevestiging via `notify.wouter`.
  - args leeg → `timer.start` zonder `duration` (gebruikt HA-native de default-duur van de helper =
    "de huidige waarde"), helper aan, bevestiging met `state_attr('timer.aircraft_monitor','duration')`.
  - `/aircraft [min|status]` ook toegevoegd aan de `/start`-hulptekst (toont ACTIEF/UIT).
- **Nieuwe automation** `1756072000002` "Aircraft monitor weer aan": trigger `timer.finished` op
  `timer.aircraft_monitor` → `input_boolean.turn_off`.
- **Bestaande** automation `1756072000001` "Vliegtuig nadert - Signal melding": extra conditie
  `state input_boolean.disable_aircraft_monitor == 'off'` (integratie blijft pollen, alleen de melding stopt).

**Belangrijke les — entity_id vs helper-`id`/`name`:**
UI-helpers in `.storage` krijgen hun **entity_id afgeleid van de `name`** (niet van het `id`-veld)
zodra HA ze de eerste keer registreert. Mijn `id: aircraft_monitor` + `name: AircraftMonitorTimer`
leverde dus eerst `timer.aircraftmonitortimer` op (en `input_boolean.aircraft_monitor_uit`), terwijl
de automations `timer.aircraft_monitor` / `input_boolean.disable_aircraft_monitor` verwachtten.
Fix: in `.storage/core.entity_registry` het `entity_id`-veld van beide registry-entries (gematcht op
`platform` + `unique_id`, waarbij `unique_id` = het helper-`id`) hernoemd naar de nette id's — precies
wat een UI-rename doet. Friendly names bleven behouden. Achtergebleven `restore_state`-sleutels van de
oude entity_id's zijn onschadelijke orphans; HA ruimt die vanzelf op.

**Werkwijze `.storage` veilig bewerken:** HA **stoppen** (`sudo systemctl stop docker-homeassistant.service`),
`.storage`-JSON bewerken, HA **starten** — anders overschrijft HA je edits bij afsluiten met zijn
geheugenkopie. `automations.yaml` mag altijd bewerkt worden (reload/herstart pikt het op).

**Backups:** `automations.yaml.bak-claude-20260826-135319`,
`.storage/timer.bak-claude-20260826-135319`, `.storage/input_boolean.bak-claude-20260826-135319`,
`.storage/core.entity_registry.bak-claude-20260826-144629`.

**Geverifieerd na herstart:** `timer.aircraft_monitor` = idle/2:00:00/restore, `input_boolean.disable_aircraft_monitor`
= off, alle drie automations `on`, geen configfouten (`hass --script check_config` schoon op de wijzigingen).

**Status:** ✅ Live. Let op: de Signal-melding gaat naar `notify.signal_maria`; de commando-bevestiging
naar `notify.wouter` (Telegram).

## Geurhal (WC) ir_detector-automation + timer restore

### Sessie 2026-08-24 - Geurhal (WC) ir_detector-automation + timer restore - OPGELOST

**Vraag:** Bestaat er een automation die de geurhal aanzet als de "ir_detector" afgaat?

**Antwoord: ja, de keten bestaat al.** De "ir_detector" is het **WCsensor** PIR-bewegingssensor
(model "Motion sensor"; de `sensor.pir_voltage` / `sensor.pir_linkquality` entities horen bij dat
device). Geen entity heet letterlijk `ir_detector`.

**HA-opzet geurhal (WC):**
- PIR/trigger: **WCsensor** → `binary_sensor.wcsensor_occupancy` (type `occupied`)
- Plug: **Tuya Smart Plug** `switch.kerstoom3hoek_stopcontact_1` (naam "Geurhalwc", device `bfbc2e57cddcfdd03dvncw`, area hal)
- Timer: `timer.geurhaltimer` (UI-helper in `.storage/timer`, duur 1u)
- Automations in `/var/lib/homeassistant/automations.yaml`:
  - `1732536224233` "WC geur aan" → occupancy on → plug aan + `timer.geurhaltimer` start
  - `1732536276607` "WC geur uit" → `timer.finished` → plug uit

**Wijziging doorgevoerd:** `timer.geurhaltimer` → `restore: false` → **`restore: true`** in
`.storage/timer` (zelfde les als bij `timer.afzuiging`: met `false` sprong de timer bij HA-herstart
stil naar idle zonder de geurhal uit te zetten). HA (container `docker-homeassistant.service`)
herstart → waarde ingelezen en na herstart geverifieerd bewaard gebleven.
Backup: `.storage/timer.bak-claude-20260824-163206`.

**Let op:** de plug is een Tuya-apparaat. Per sessie 2026-08-23 was de Tuya-integratie kapot sinds
17 aug; user gaf aan dat Tuya het weer zou doen. Als de geurhal niet reageert terwijl de automation
wél vuurt → check eerst de Tuya-koppeling (zelfde oorzaak als bij de afzuiging).

**Status:** ✅ `restore: true` live; automation-keten compleet mits Tuya werkt.

## Afzuiging gaat wel aan maar niet uit

### Sessie 2026-08-23 - Afzuiging gaat wel aan maar niet uit - DEELS OPGELOST

**Probleem:** Centrale afzuiging (keuken) ging wel aan maar niet meer automatisch uit. Knop (RODRET) deed het slecht.

**HA-opzet afzuiging:**
- Stekker: **Tuya Smart Plug** `switch.afzuiging_socket_1` (device `bf4193cbb9e7c8307efsqq`)
- Knop: **IKEA RODRET** `afzuigingknop` via zigbee2mqtt (`0x5cc7c1fffe405825`)
- Timer: `timer.afzuiging` (UI-helper in `.storage/timer`, duur 1u)
- Automations in `/var/lib/homeassistant/automations.yaml`:
  - `1771177871263` "Centrale afzuiging aan" → knop-on/switch-on → stekker aan + timer start
  - `2024112501` "Centrale afzuiging uit" → `timer.finished` → stekker uit
- Let op: entity-slugs misleidend — `automation.centrale_afzuiging_uit_2/_3/_4` zijn NIET allemaal afzuiging (uit_2 = de "aan"; uit_3/_4 = Geurzolder/Geurwerkkamer, oude slugs).

**Hoofdoorzaak (nog handmatig op te lossen):**
**Tuya-integratie kapot sinds 17 aug** — log toont `tuya_sharing ApiRequestException: sign invalid` en `API_QPS_LIMIT_OR_DEGRADE`. HA kan de Tuya-stekker niet meer betrouwbaar uitzetten of uitlezen (`binary_sensor.afzuiging_status` stond vast op `off` sinds 17 aug). Automations vuren correct, maar de `switch.turn_off` naar de Tuya-cloud mislukt → afzuiging blijft aan.

**Handmatig te doen (kan niet vanuit CLI):**
1. HA-UI → Instellingen → Apparaten & Diensten → **Tuya** → herconfigureren / opnieuw inloggen (tokens verlopen).
2. **Dubbele Tuya-entry** opruimen (`tuya` + `tuya@toorren.net` — hou die met apparaten).
3. RODRET-batterij vervangen (CR2032; stond op 10% / 1100 mV).

**Config-verbeteringen (doorgevoerd + getest via HA-restart):**
- Nieuwe automation `1771177871264` "Centrale afzuiging uit (knop)": OFF-knop → stekker uit + `timer.cancel`. (OFF-trigger weggehaald uit de "aan"-automation, die zette de afzuiging juist aan.)
- `timer.afzuiging` → `restore: true` in `.storage/timer` (voorheen `false`: bij HA-herstart sprong de timer stil naar idle zonder de afzuiging uit te zetten).
- Backups: `automations.yaml.bak-claude-20260823-212801`, `.storage/timer.bak-claude-20260823-212801`.

**Status:** ⏳ Config-verbeteringen live; hele keten werkt pas weer als Tuya opnieuw is gekoppeld.
