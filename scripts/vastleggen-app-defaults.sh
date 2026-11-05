#!/usr/bin/env bash
# Gouden app-config van maaike vastleggen: haalt de niet-geheime config van mpenzi op, filtert
# regels met tokens/wachtwoorden/cookies eruit en toont per bestand een diff met
# home/profiles/maaike/defaults/ voordat er iets wordt overschreven.
#
#   scripts/vastleggen-app-defaults.sh [ssh-doel]      (standaard wtoorren@10.77.0.3)
#
# Draai vanaf lobos, in de repo. sudo op mpenzi vraagt één keer het wachtwoord van wtoorren.
# Niet vastgelegd: Spotify-prefs (agenix, zie docs/maaike-app-defaults.md), Signal (sleutel in
# config.json), Bitwarden (data.json bevat de kluis; de seed staat in seeds.nix).
set -euo pipefail

target=${1:-wtoorren@10.77.0.3}
repo=$(git rev-parse --show-toplevel)
dest="$repo/home/profiles/maaike/defaults"

# naam in defaults/ -> pad onder /home/maaike
declare -A files=(
  [nextcloud.cfg]=.config/Nextcloud/nextcloud.cfg
  [ZapZap.conf]=.config/ZapZap/ZapZap.conf
)

# Sleutels (deel vóór '=') die op een geheim wijzen. Hoofdletterongevoelig.
secret_keys='token|password|passwd|secret|cookie|session|encryptedkey|privatekey|api_?key|credential'

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

remote_tar=vastleggen-app-defaults.tar
echo "Ophalen van $target (sudo-wachtwoord van wtoorren)..."
# -t voor de sudo-prompt; de tar gaat naar een bestand op mpenzi, niet door de tty.
ssh -t "$target" "sudo tar -C /home/maaike --ignore-failed-read -cf - ${files[*]} > $remote_tar"
scp -q "$target:$remote_tar" "$tmp/"
ssh "$target" rm -f "$remote_tar"
tar -C "$tmp" -xf "$tmp/$remote_tar"

changed=()
for name in "${!files[@]}"; do
  src="$tmp/${files[$name]}"
  if [[ ! -f "$src" ]]; then
    echo "-- $name: niet gevonden op $target, overgeslagen"
    continue
  fi
  filtered="$tmp/$name.filtered"
  grep -viE "^[^=]*(${secret_keys})[^=]*=" "$src" > "$filtered" || true
  dropped=$(( $(wc -l < "$src") - $(wc -l < "$filtered") ))
  (( dropped == 0 )) || echo "-- $name: $dropped regel(s) met een geheim weggelaten"

  if cmp -s "$filtered" "$dest/$name"; then
    echo "-- $name: ongewijzigd"
    continue
  fi
  echo "-- $name: verschil met de repo"
  diff -u --label "repo/$name" --label "mpenzi/$name" "$dest/$name" "$filtered" || true
  changed+=("$name")
done

(( ${#changed[@]} )) || { echo "Niets te doen."; exit 0; }

read -r -p "Deze ${#changed[@]} bestand(en) overnemen in home/profiles/maaike/defaults/? [j/N] " ok
[[ "$ok" == [jJ] ]] || { echo "Niets geschreven."; exit 0; }
for name in "${changed[@]}"; do
  cp "$tmp/$name.filtered" "$dest/$name"
  echo "geschreven: $dest/$name"
done
echo "Controleer met git diff, commit en deploy mpenzi. Bestaande bestanden bij maaike blijven"
echo "staan; met 'sudo herstel-app maaike <app>' gaat de nieuwe standaard erin."
