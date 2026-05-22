# Checklist na stroomstoring - malandro

## 1. Redis (Authelia)

Redis slaat Authelia sessies op als RDB dump. Na een NixOS upgrade kan de dump incompatibel zijn met de nieuwe Redis versie (`Can't handle RDB format version X`).

**Symptoom:** Alle services achter Authelia geven 500/502, auth.toorren.net onbereikbaar.

```bash
sudo systemctl status redis-authelia.service
# Fout: "Can't handle RDB format version X"

sudo rm /var/lib/redis-authelia/dump.rdb
sudo systemctl restart redis-authelia.service
sudo systemctl restart authelia-main.service
```

> De dump bevat alleen sessie-data (ingelogde gebruikers). Verwijderen is veilig - iedereen moet opnieuw inloggen.

---

## 2. Postfix

Postfix kan na een stroomstoring of rebuild niet starten door dependency timing.

**Symptoom:** Authelia start niet (`failed to dial connection: dial tcp [::1]:25`).

```bash
sudo systemctl status postfix.service
sudo systemctl start postfix.service
```

> Authelia heeft Postfix nodig voor e-mailnotificaties. Start Postfix eerst, dan pas Authelia.

---

## 3. Authelia

Start automatisch op na Redis en Postfix, maar soms moet je handmatig triggeren.

```bash
sudo systemctl restart authelia-main.service
sudo systemctl status authelia-main.service
# Verwacht: "Startup complete" en "Listening on 127.0.0.1:9091"
```

---

## 4. PostgreSQL + Vikunja

PostgreSQL start soms trager op dan Vikunja verwacht, waardoor Vikunja zijn restart-limiet bereikt en in `failed` toestand blijft hangen.

**Symptoom:** Vikunja gefailed (`Migration failed: dial tcp [::1]:5432: connect: connection refused`).

```bash
sudo systemctl status postgresql.service
sudo systemctl status vikunja.service

# PostgreSQL moet draaien voordat je Vikunja herstart
sudo systemctl restart vikunja.service
sudo systemctl status vikunja.service
# Verwacht: "HTTP server listening on 127.0.0.1:8093"
```

> Vikunja slaat zijn restart-limiet op bij boot. Een handmatige restart na boot werkt altijd zodra PostgreSQL actief is.

---

## 5. Docker containers

Controleer of alle containers draaien:

```bash
sudo docker ps --format "table {{.Names}}\t{{.Status}}"
```

Verwachte containers: `homeassistant`, `zigbee2mqtt`, `mosquitto`, `invoiceplane`, `erugo`, `bentopdf`, `wg-easy`, `vaultwarden`, `baikal`, `infcloud`, `signal-cli`, `docseal`, `wg-easy`, `paperless-webserver-1`, `paperless-broker-1`, `it-tools`, `bentopdf`, `registry-mirror`, `fail2bancontrol`

Individuele container herstarten:

```bash
sudo systemctl restart docker-<naam>.service
# Bijvoorbeeld:
sudo systemctl restart docker-homeassistant.service
sudo systemctl restart docker-zigbee2mqtt.service
```

---

## 6. Zigbee2MQTT

Na een stroomstoring kan de Zigbee USB dongle in een slechte staat zitten.

**Symptoom:** Zigbee2MQTT logt alleen ping-requests zonder respons.

```bash
sudo journalctl -u docker-zigbee2mqtt.service -n 30
# Goed: "Zigbee2MQTT started", MQTT publishes zichtbaar
# Slecht: alleen "zh:zstack:znp: --> SREQ: SYS - ping" zonder respons
```

Als de dongle niet reageert:

```bash
# Controleer of het device aanwezig is
ls -la /dev/zigbee
ls -la /dev/serial/by-id/

# Container herstarten
sudo systemctl restart docker-zigbee2mqtt.service

# Als dat niet helpt: server rebooten om USB te resetten
sudo reboot
```

> Belangrijk: Home Assistant mag /dev/ttyUSB1 (Zigbee dongle) NIET hebben - alleen zigbee2mqtt gebruikt die.
> Home Assistant gebruikt /dev/ttyUSB0 (DSMR P1 meter).

---

## 7. Globale statuscheck

```bash
# Gefaalde services
sudo systemctl --failed

# Alle relevante services in één keer
sudo systemctl status redis-authelia authelia-main postfix nginx --no-pager -l

# Docker containers
sudo docker ps --format "table {{.Names}}\t{{.Status}}"

# Nginx errors
sudo journalctl -u nginx --no-pager -n 20 | grep error
```

---

## Volgorde bij volledig herstel

1. `sudo systemctl start postfix.service`
2. `sudo systemctl restart redis-authelia.service` (verwijder dump.rdb eerst indien nodig)
3. `sudo systemctl restart authelia-main.service`
4. `sudo systemctl restart vikunja.service` (als PostgreSQL actief is)
5. Controleer nginx: `sudo systemctl status nginx`
6. Controleer Docker containers: `sudo docker ps`
7. Test een service: open https://auth.toorren.net
