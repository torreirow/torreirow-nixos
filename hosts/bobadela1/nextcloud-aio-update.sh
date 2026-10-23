#!/usr/bin/env bash
# Dagelijkse Nextcloud AIO-update (zonder borg-backup) op lokale tijd.
#
# AIO's eigen "daily backup + automatic updates" draait altijd op UTC; deze wrapper wordt door
# nextcloud-aio-update.timer (Europe/Amsterdam) aangeroepen. Zie hosts/bobadela1/README.md.
#
# /daily-backup.sh werkt eerst de mastercontainer bij. Gebeurt dat, dan wordt de container
# vervangen en sneuvelt deze `docker exec` halverwege; AIO schrijft zelf voor het script dan
# een tweede keer te draaien. We doen die tweede run alleen als de mastercontainer echt
# herstart is, anders zou elke dag een dubbele stop/start (= dubbele downtime) volgen.
set -uo pipefail

MC=nextcloud-aio-mastercontainer

started() { docker inspect "$MC" --format '{{.State.StartedAt}}' 2>/dev/null; }

run_update() {
    docker exec --env AUTOMATIC_UPDATES=1 --env DAILY_BACKUP=0 "$MC" /daily-backup.sh
}

wait_healthy() {
    for _ in $(seq 1 60); do
        [ "$(docker inspect "$MC" --format '{{.State.Health.Status}}' 2>/dev/null)" = healthy ] && return 0
        sleep 10
    done
    echo "mastercontainer niet healthy na 10 min" >&2
    return 1
}

before=$(started)
run_update
rc=$?

if [ "$(started)" != "$before" ]; then
    echo "mastercontainer is bijgewerkt en herstart; tweede run voor de overige containers"
    wait_healthy || exit 1
    run_update
    rc=$?
fi

exit "$rc"
