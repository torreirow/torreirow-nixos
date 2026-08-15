# USB Dongles: Zigbee & DSMR — stabiele device paden (malandro)

**Laatst bijgewerkt:** 2026-08-06

## Kernpunt

Op malandro zitten twee USB-serieel apparaten:

| Symlink | Apparaat | Herkend aan (udev) |
|---------|----------|--------------------|
| `/dev/zigbee` | Sonoff Zigbee 3.0 USB Dongle Plus (Silicon Labs) | `idVendor=10c4`, `idProduct=ea60`, `serial=0001` |
| `/dev/dsmr` | FTDI FT232R USB UART — DSMR P1 slimme meter | `idVendor=0403`, `idProduct=6001`, `serial=AQ78GLG6` |

De `/dev/ttyUSB*` nummers zijn **niet stabiel** en kunnen bij elke boot verwisselen.
Daarom gebruiken we **nooit** `ttyUSB0`/`ttyUSB1` direct, maar de symlinks
`/dev/zigbee` en `/dev/dsmr` die via udev op serienummer worden aangemaakt.

## Waar staat dit geconfigureerd

`modules/hassio/default.nix`:

- **udev-regels** (`services.udev.extraRules`) maken de symlinks aan op basis van
  vendor/product/serial:
  ```
  SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", ATTRS{serial}=="0001", SYMLINK+="zigbee"
  SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", ATTRS{serial}=="AQ78GLG6", SYMLINK+="dsmr"
  ```
- **Zigbee2MQTT container** krijgt `--device=/dev/zigbee:/dev/zigbee`, en de config
  `configuration.yaml` heeft `serial.port: /dev/zigbee`.
- **Home Assistant container** krijgt `--device=/dev/dsmr:/dev/dsmr` (DSMR P1 meter).
- **`zigbee-usb-reset.service`** doet eenmalig bij BOOT een USB unbind/bind van de
  Zigbee coordinator (vendor `10c4`) vóór `docker-zigbee2mqtt.service`, om een
  SRSP-SYS ping timeout na een crash te voorkomen. Draait bewust **alleen bij boot**,
  niet bij elke Z2M herstart (herhaald resetten geeft juist commissioning timeouts).

## Sessie 2026-08-06 — USB-swap na poweroff — GEEN PROBLEEM

**Aanleiding:** malandro moest tijdelijk uit. Bij een vorige keer verwisselden de
USB-poorten, wat vroeger problemen gaf met de Zigbee dongle en DSMR adapter.

**Wat er gebeurde:** de poorten verwisselden inderdaad opnieuw:

| | Vóór poweroff | Ná boot |
|---|---|---|
| `/dev/zigbee` (Sonoff) | `ttyUSB0` | `ttyUSB1` |
| `/dev/dsmr` (FTDI) | `ttyUSB1` | `ttyUSB0` |

**Resultaat:** geen enkel probleem. Omdat de symlinks op serienummer matchen,
bleven `/dev/zigbee` en `/dev/dsmr` naar het juiste fysieke apparaat wijzen.
De containers merkten er niets van.

**Verificatie na boot:**
- `ls -la /dev/zigbee /dev/dsmr` → beide symlinks aanwezig, wijzend naar de
  (verwisselde) ttyUSB-nodes.
- `docker ps` → `zigbee2mqtt` en `homeassistant` beide `Up`.
- `systemctl is-active docker-zigbee2mqtt docker-homeassistant zigbee-usb-reset`
  → alle drie `active`.
- `docker logs zigbee2mqtt` → live berichten van devices (bijv. `WCsensor`) worden
  ontvangen en naar MQTT gepubliceerd → coordinator verbonden, geen ping-timeout.

**Les:** de poort-verwisseling is by design onschadelijk. Verwijs voortaan naar
de symlinks, nooit naar `ttyUSB*`.

## Checklist na een reboot / poweroff

```bash
# 1. Symlinks aanwezig en wijzend naar een ttyUSB-node?
ls -la /dev/zigbee /dev/dsmr

# 2. Welk fysiek apparaat zit achter welke ttyUSB (serienummer-check)?
ls -la /dev/serial/by-id/
#   usb-Silicon_Labs_Sonoff_Zigbee_3.0_USB_Dongle_Plus_0001-if00-port0 -> zigbee
#   usb-FTDI_FT232R_USB_UART_AQ78GLG6-if00-port0                        -> dsmr

# 3. Containers draaien?
docker ps --format '{{.Names}}\t{{.Status}}' | grep -iE 'zigbee|homeassistant'

# 4. Services actief?
systemctl is-active docker-zigbee2mqtt docker-homeassistant zigbee-usb-reset

# 5. Z2M echt verbonden met coordinator (niet alleen "running")?
docker logs zigbee2mqtt 2>&1 | tail -20   # verwacht: MQTT publish van devices
```

## Als een symlink ontbreekt na boot

- Controleer of het apparaat fysiek gezien wordt: `ls -la /dev/serial/by-id/`.
- Klopt het serienummer nog? Bij vervanging van een dongle wijzigt het serienummer
  en moet de udev-regel in `modules/hassio/default.nix` worden bijgewerkt.
- udev-regels opnieuw toepassen zonder reboot:
  `sudo udevadm control --reload && sudo udevadm trigger`
- Zigbee coordinator vastgelopen (SRSP-SYS ping timeout)? Herstart de reset-service
  en daarna de container:
  `sudo systemctl restart zigbee-usb-reset && sudo systemctl restart docker-zigbee2mqtt`

## Zie ook

- `modules/hassio/default.nix` — bron van udev-regels, containers en reset-service
- `ZIGBEE_MIGRATION_LOG.md` — Zigbee netwerk/coordinator historie
- `docs/na-stroomstoring.md` — herstel na stroomuitval
