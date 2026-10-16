#!/usr/bin/env bash
# Updates voor lobos en malandro (NixOS): firmware via fwupd, systeem via de
# flake-checkout. Pakketupdates komen niet uit apt maar uit flake.lock in de
# repo; dit script haalt die op (git pull) en bouwt — het werkt de lock niet bij.

set -uo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Dit script moet als root worden uitgevoerd: sudo update-system $*"
    exit 1
fi

USER_NAME="${SUDO_USER:-wtoorren}"
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
REPO="$USER_HOME/data/git/torreirow/torreirow-nixos"
HOST=$(hostname -s)

case "$HOST" in
    lobos)    HM_CONFIG="wtoorren@linuxdesktop"; HM_EXTRA=(--impure) ;;
    malandro) HM_CONFIG="wtoorren@linuxserver";  HM_EXTRA=() ;;
    *)        echo "Onbekende host '$HOST' (alleen lobos en malandro)"; exit 1 ;;
esac

usage() {
    echo "Gebruik: sudo update-system <fetch|update>"
    echo ""
    echo "  fetch   Laat beschikbare firmware- en repo-updates zien zonder te installeren"
    echo "  update  Firmware bijwerken, repo pullen, NixOS + home-manager switchen, oude generaties opruimen"
    exit 1
}

# git en home-manager draaien als de eigenaar van de checkout, niet als root.
# sudo's secure_path kent het home-manager-profiel niet, dus PATH expliciet.
# sudo wist ook SSH_AUTH_SOCK; git fetch over ssh heeft de rbw-agent nodig
# (~/.ssh/rbw-keys bevat alleen publieke sleutels).
as_user() {
    sudo -u "$USER_NAME" -H env \
        PATH="/etc/profiles/per-user/$USER_NAME/bin:$USER_HOME/.nix-profile/bin:/run/current-system/sw/bin" \
        SSH_AUTH_SOCK="/run/user/$(id -u "$USER_NAME")/rbw/ssh-agent-socket" \
        "$@"
}

firmware_refresh() {
    echo "==> Firmware: remote inschakelen en metadata vernieuwen..."
    yes | fwupdmgr enable-remote lvfs-testing
    fwupdmgr refresh --force
}

repo_fetch() {
    echo ""
    echo "==> Repo ophalen ($REPO, branch $(as_user git -C "$REPO" rev-parse --abbrev-ref HEAD))..."
    as_user git -C "$REPO" fetch --quiet || return 1
    local behind
    behind=$(as_user git -C "$REPO" rev-list --count 'HEAD..@{u}')
    if [[ "$behind" -eq 0 ]]; then
        echo "Repo is bij."
    else
        echo "$behind nieuwe commit(s):"
        as_user git -C "$REPO" log --oneline 'HEAD..@{u}'
    fi
}

cmd_fetch() {
    firmware_refresh
    fwupdmgr get-updates

    repo_fetch
}

cmd_update() {
    firmware_refresh
    fwupdmgr update

    repo_fetch || { echo "git fetch mislukt, stop."; exit 1; }
    echo ""
    echo "==> Repo bijwerken..."
    as_user git -C "$REPO" pull --ff-only || { echo "git pull mislukt (lokale wijzigingen?), stop."; exit 1; }

    echo ""
    echo "==> NixOS switchen (.#$HOST)..."
    (cd "$REPO" && nixos-rebuild switch --flake ".#$HOST") || { echo "nixos-rebuild mislukt, stop."; exit 1; }

    echo ""
    echo "==> Home-manager switchen (.#$HM_CONFIG)..."
    (cd "$REPO" && as_user home-manager switch --flake ".#$HM_CONFIG" \
        --extra-experimental-features nix-command "${HM_EXTRA[@]}" -b "backup-$(date +%s)") \
        || { echo "home-manager switch mislukt, stop."; exit 1; }

    # Tegenhanger van apt autoremove: zonder dit loopt /nix/store vol
    # (malandro stond op 125 systeemgeneraties en een volle root).
    echo ""
    echo "==> Generaties ouder dan 14 dagen opruimen..."
    nix-collect-garbage --delete-older-than 14d
    as_user nix-collect-garbage --delete-older-than 14d
}

case "${1:-}" in
    fetch)  cmd_fetch ;;
    update) cmd_update ;;
    *)      usage ;;
esac
