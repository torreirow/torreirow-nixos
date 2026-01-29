# Zigbee Adapter Migratie Log - 29 Januari 2026

## Probleem
- Zigbee adapter (Sonoff Zigbee 3.0 USB Dongle Plus) veranderde van `/dev/ttyUSB0` naar `/dev/ttyUSB1` na stroominderbreking
- ZHA (Zigbee Home Automation) in Home Assistant kreeg continu "Network settings do not match most recent backup" error
- 19 Zigbee apparaten niet meer bereikbaar
- Restore van backup bleef hangen of faalde

## Uitgevoerde Acties

### 1. Poging: Zigbee2MQTT Migratie
**Doel:** Migreren van ZHA naar Zigbee2MQTT (stabieler platform)

**Configuratie:**
- Mosquitto MQTT broker geïnstalleerd (poort 1883, 9001)
- Zigbee2MQTT container geconfigureerd (poort 8086)
- Nginx reverse proxy: https://zigbee.toorren.net
- Module aangemaakt: `/home/wtoorren/data/git/torreirow-nixos/modules/mqtt.nix`

**Netwerk Informatie Geëxtraheerd uit ZHA Database:**
```bash
# Uit /var/lib/homeassistant/zigbee.db (table: network_backups_v13)
Network Key: [81, 78, 209, 197, 7, 198, 221, 85, 101, 211, 183, 171, 21, 187, 174, 167]
PAN ID: 36233 (0x8D89)
Extended PAN ID: [98, 121, 122, 121, 39, 175, 253, 12]
Channel: 11
```

**Zigbee2MQTT Configuratie:**
- Locatie: `/var/lib/zigbee2mqtt/configuration.yaml`
- Device: `/dev/serial/by-id/usb-Silicon_Labs_Sonoff_Zigbee_3.0_USB_Dongle_Plus_0001-if00-port0`
- Adapter: ember (eerst ezsp geprobeerd, toen ember)
- Baudrate: 115200

**Resultaat: GEFAALD**
- Error: `Failed to start EZSP layer with status=HOST_FATAL_ERROR`
- Oorzaak: Firmware incompatibiliteit tussen Sonoff Zigbee 3.0 USB Dongle Plus en nieuwste Zigbee2MQTT versie
- Container crashte continu na meerdere ASH adapter resets

### 2. Poging: Terug naar ZHA met Backup Restore
**Doel:** ZHA opnieuw configureren met backup van 27 januari

**Backup Informatie:**
- Primaire backup: 27 januari 2026 (laatste werkende staat)
- Secundaire backup: 11 oktober 2023 (oud maar mogelijk stabiel)
- Backup locatie: `/tmp/homeassistant/zigbee.db`

**Configuratie geprobeerd:**
- Device pad: `/dev/serial/by-id/usb-Silicon_Labs_Sonoff_Zigbee_3.0_USB_Dongle_Plus_0001-if00-port0`
- Radio type: EZSP
- Serial port speed: 115200
- Flow control geprobeerd: hardware, software, none

**Resultaat: GEFAALD**
- Alle flow control opties gaven "Failed to connect"
- Restore van 27 januari backup bleef hangen of faalde
- Adapter leek in "stuck" staat te zitten

### 3. Poging: Nieuw ZHA Netwerk met Geïmporteerde Keys
**Doel:** Nieuw netwerk aanmaken en oude netwerk keys importeren

**Status: NIET VOLTOOID**
- Plan was om "Erase and create new network" te gebruiken
- Dan netwerk keys handmatig importeren
- Alle connection attempts faalden voor het netwerk aangemaakt kon worden

## Huidige Staat

### Systeem Configuratie
- **OS:** NixOS 25.11
- **Home Assistant:** Docker container (ghcr.io/home-assistant/home-assistant:stable)
- **Zigbee Adapter:** Sonoff Zigbee 3.0 USB Dongle Plus
- **Huidig device pad:** `/dev/ttyUSB1` (symlink via `/dev/serial/by-id/...`)
- **Aantal Zigbee devices:** 19 apparaten

### Modules Aangemaakt
1. `/home/wtoorren/data/git/torreirow-nixos/modules/mqtt.nix`
   - Mosquitto MQTT broker configuratie
   - Zigbee2MQTT container configuratie (niet werkend)
   - Nginx reverse proxy voor https://zigbee.toorren.net

2. `/home/wtoorren/data/git/torreirow-nixos/PORTS.md`
   - Overzicht van alle gebruikte poorten op het systeem
   - Helpt bij conflict preventie

### Backups
- **Originele zigbee.db:** `/var/lib/homeassistant/zigbee.db.before-z2m-migration`
- **Broken state:** `/var/lib/homeassistant/zigbee.db.broken`
- **Backup staat:** `/tmp/homeassistant/zigbee.db` (27 januari)
- **Config entries backup:** `/tmp/homeassistant/.storage/core.config_entries`

### Services Status
- **Home Assistant:** Draait (poort 8123)
- **Mosquitto:** Draait (poort 1883, 9001)
- **Zigbee2MQTT:** Gestopt en disabled (werkt niet)

## Diagnose

### Root Cause
De Sonoff Zigbee 3.0 USB Dongle Plus lijkt in een problematische staat te zitten na:
1. Meerdere mislukte Zigbee2MQTT verbindingspogingen (EZSP resets)
2. Meerdere mislukte ZHA verbindingspogingen
3. Device pad wisseling van ttyUSB0 naar ttyUSB1

### Waarom Zigbee2MQTT Faalde
- Firmware op de Sonoff adapter is te oud voor de nieuwste Zigbee2MQTT/zigbee-herdsman versie
- EZSP/Ember stack krijgt `HOST_FATAL_ERROR` bij initialisatie
- Adapter vereist waarschijnlijk firmware update (zie: https://github.com/Koenkk/zigbee2mqtt/discussions/21462)

### Waarom ZHA Faalde
- Adapter lijkt "stuck" in foutieve staat
- Alle flow control opties (hardware/software/none) falen
- USB stack moet waarschijnlijk volledig gereset worden

## Volgende Stappen NA REBOOT

### Stap 1: Verifieer Adapter Status
```bash
# Check of adapter nog steeds op ttyUSB1 zit
ls -la /dev/serial/by-id/ | grep Sonoff
readlink -f /dev/serial/by-id/usb-Silicon_Labs_Sonoff_Zigbee_3.0_USB_Dongle_Plus_0001-if00-port0

# Check of Home Assistant draait
curl http://127.0.0.1:8123
```

### Stap 2: ZHA Configureren
1. Ga naar Home Assistant: https://homeassistant.toorren.net
2. Settings > Devices & Services
3. Klik **+ ADD INTEGRATION**
4. Zoek **Zigbee Home Automation**

### Stap 3: Adapter Selectie
**Optie A: Automatische detectie (probeer dit eerst)**
- Selecteer de Sonoff adapter als deze verschijnt
- Laat ZHA automatisch de settings detecteren

**Optie B: Manual adapter config (als auto-detect niet werkt)**
```
Serial device path: /dev/serial/by-id/usb-Silicon_Labs_Sonoff_Zigbee_3.0_USB_Dongle_Plus_0001-if00-port0
Radio type: EZSP
Serial port speed: 115200
Flow control: hardware (of probeer: none)
```

### Stap 4: Backup Restore
**Primaire optie:** Backup van 27 januari 2026
- Selecteer "Restore an automatic backup"
- Kies de backup van "27 jan"
- Dit zou alle 19 apparaten moeten herstellen

**Fallback optie:** Backup van 11 oktober 2023
- Als 27 januari blijft falen
- Oudere backup maar mogelijk stabieler
- Apparaten zouden moeten reconnecten als netwerk keys gelijk zijn

**Laatste optie:** Nieuw netwerk
- "Erase network settings and create a new network"
- Alle 19 apparaten moeten opnieuw gepaired worden

## Nuttige Commando's

### Check ZHA Status
```bash
# Check Home Assistant logs voor ZHA
sudo docker logs homeassistant 2>&1 | grep -i "zha\|zigbee" | tail -50

# Check of er ZHA errors zijn
sudo docker logs homeassistant 2>&1 | grep -E "ERROR.*zha"
```

### Check Adapter
```bash
# Check of adapter beschikbaar is
ls -la /dev/serial/by-id/ | grep Sonoff

# Check welk proces de adapter gebruikt
sudo fuser /dev/ttyUSB1
```

### Restart Services
```bash
# Restart alleen Home Assistant
sudo systemctl restart docker-homeassistant.service

# Check status
sudo systemctl status docker-homeassistant.service
```

## Netwerk Configuratie (voor referentie)

Als je ooit handmatig de netwerk settings moet invoeren in ZHA:

```yaml
Network Key: [81, 78, 209, 197, 7, 198, 221, 85, 101, 211, 183, 171, 21, 187, 174, 167]
PAN ID: 36233 (hex: 0x8D89)
Extended PAN ID: [98, 121, 122, 121, 39, 175, 253, 12]
Channel: 11
```

## Lessons Learned

1. **Gebruik altijd `/dev/serial/by-id/` paden** in plaats van `/dev/ttyUSBx`
   - Dit voorkomt problemen bij device path wijzigingen

2. **Zigbee2MQTT vereist compatibele firmware**
   - Sonoff Zigbee 3.0 USB Dongle Plus heeft mogelijk firmware update nodig
   - ZHA is soms eenvoudiger maar minder flexibel

3. **USB adapters kunnen "stuck" raken**
   - Reboot is vaak de beste oplossing
   - Multiple connection attempts kunnen adapter in slechte staat brengen

4. **Maak regelmatig backups van zigbee.db**
   - Bewaar meerdere versies
   - Test backup restore voordat je het nodig hebt

5. **Port mapping documenteren is belangrijk**
   - Zie `/home/wtoorren/data/git/torreirow-nixos/PORTS.md`
   - Voorkomt port conflicten bij nieuwe services

## Contact Informatie

Voor verdere hulp:
- ZHA Documentation: https://www.home-assistant.io/integrations/zha/
- Zigbee2MQTT Documentation: https://www.zigbee2mqtt.io/
- Sonoff Firmware Updates: https://sonoff.tech/product-review/how-to-flash-the-firmware-for-sonoff-zigbee-3-0-usb-dongle-plus/

## Datum & Status
- **Datum:** 29 Januari 2026
- **Status:** Wachtend op reboot om USB adapter te resetten
- **Volgende actie:** Na reboot ZHA configureren met backup restore
