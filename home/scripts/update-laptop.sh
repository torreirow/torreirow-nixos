#!/usr/bin/env bash

if [[ $EUID -ne 0 ]]; then
    echo "Dit script moet als root worden uitgevoerd: sudo $0 $*"
    exit 1
fi

usage() {
    echo "Gebruik: sudo $0 <fetch|update>"
    echo ""
    echo "  fetch   Haal beschikbare updates op zonder te installeren"
    echo "  update  Installeer alle beschikbare updates"
    exit 1
}

cmd_fetch() {
    echo "==> Firmware: remote inschakelen en updates ophalen..."
    yes | fwupdmgr enable-remote lvfs-testing
    fwupdmgr refresh --force
    fwupdmgr get-updates

    echo ""
    echo "==> Pakketlijsten vernieuwen..."
    apt update

    echo ""
    echo "==> Beschikbare pakketupdates:"
    apt list --upgradable 2>/dev/null
}

cmd_update() {
    echo "==> Firmware updaten..."
    yes | fwupdmgr enable-remote lvfs-testing
    fwupdmgr refresh --force
    fwupdmgr update

    echo ""
    echo "==> Systeempakketten updaten..."
    apt update
    apt upgrade -y
    apt autoremove -y
}

case "${1:-}" in
    fetch)  cmd_fetch ;;
    update) cmd_update ;;
    *)      usage ;;
esac
