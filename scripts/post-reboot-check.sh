#!/usr/bin/env bash
# Post-reboot check na SATA link-drop /dev/sdb (Intenso SSD) - 2026-08-25
# Draai: sudo bash post-reboot-check.sh
set +e
LOG=/var/log/post-reboot-check.log
exec > >(tee -a "$LOG") 2>&1
echo "==================== $(date) ===================="
echo "### 1. Is /dev/sdb terug op de bus?"
lsblk -o NAME,SIZE,MODEL,SERIAL,MOUNTPOINT /dev/sdb 2>&1 || echo "!! /dev/sdb NIET aanwezig -> schijf/kabel fysiek nakijken"
echo
echo "### 2. Verse I/O errors op sdb sinds boot?"
dmesg -T 2>&1 | grep -iE "I/O error, dev sdb|EXT4-fs \(sdb1\)|ata2.*link down" | tail -10
echo "(leeg = goed)"
echo
echo "### 3. Mount status /data/external (verwacht: rw, GEEN emergency_ro)"
findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS /data/external 2>&1 || echo "!! niet gemount"
echo
echo "### 4. Read-write test"
touch /data/external/.rwtest 2>&1 && echo "RW OK" && rm -f /data/external/.rwtest || echo "!! nog steeds READ-ONLY / I/O error"
echo
echo "### 5. Docker daemon"
systemctl is-active docker.service
docker ps --format "table {{.Names}}\t{{.Status}}" 2>&1 || echo "!! docker daemon niet bereikbaar"
echo
echo "### 6. Gefaalde services"
systemctl --failed --no-pager
echo
echo "### 7. Kern-auth-stack"
for s in redis-authelia authelia-main postfix nginx postgresql vikunja; do printf "%-18s %s\n" "$s" "$(systemctl is-active $s)"; done
echo

echo "### 8. USB dongles Zigbee/DSMR (symlinks op serienummer, zie docs/usb-dongles.md)"
ls -la /dev/zigbee /dev/dsmr 2>&1 || echo "!! symlink(s) ONTBREKEN -> check /dev/serial/by-id/ en udev-regels in modules/hassio/default.nix"
echo "-- fysieke apparaten (by-id) --"
ls -la /dev/serial/by-id/ 2>&1 || echo "!! geen serial by-id -> dongle fysiek niet gezien"
echo

echo "### 9. Verwachte Docker-containers draaien? (State + Health)"
EXPECTED="homeassistant zigbee2mqtt mosquitto paperless-webserver-1 paperless-broker-1 vaultwarden baikal signal-cli wg-easy"
for c in $EXPECTED; do
  st=$(docker inspect -f '{{.State.Status}}{{if .State.Health}} ({{.State.Health.Status}}){{end}}' "$c" 2>/dev/null)
  [ -z "$st" ] && st="!! ONTBREEKT / niet gevonden"
  printf "%-24s %s\n" "$c" "$st"
done
echo

echo "### 10. Zigbee2MQTT verbonden met coordinator? (niet alleen 'running')"
systemctl is-active docker-zigbee2mqtt zigbee-usb-reset 2>&1
docker logs --tail 25 zigbee2mqtt 2>&1 | grep -iE "coordinator|connect|Currently .* devices|MQTT|error|timeout|failed" | tail -12
echo "(verwacht: 'Currently N devices are joined' / MQTT publishes; GEEN ping/SRSP-timeout)"
echo

echo "### 11. Home Assistant DSMR-device zichtbaar in container?"
systemctl is-active docker-homeassistant 2>&1
docker exec homeassistant sh -c 'ls -la /dev/dsmr' 2>&1 || echo "!! /dev/dsmr niet in HA-container -> --device mapping / symlink check"
echo

echo "### 12. Linger + tmux user-service (na linger-fix 2026-08-28)"
loginctl show-user wtoorren -p Linger 2>&1
runuser -u wtoorren -- env XDG_RUNTIME_DIR=/run/user/$(id -u wtoorren) systemctl --user is-active tmux.service 2>&1
runuser -u wtoorren -- tmux -L default ls 2>&1 | grep -q '^main:' && echo "tmux 'main'-sessie AANWEZIG" || echo "!! tmux 'main'-sessie ontbreekt"
echo "==================== EINDE ===================="
