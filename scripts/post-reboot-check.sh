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
echo "==================== EINDE ===================="
