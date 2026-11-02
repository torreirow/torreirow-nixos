#!/usr/bin/env bash
# Run the upload page locally on port 18111 (another port: FILEDROP_DEV_PORT=18121 ./dev.sh).
# Listens on 0.0.0.0 so a phone on the LAN can reach it (only localhost: FILEDROP_DEV_BIND=127.0.0.1).
# The malandro firewall blocks the port, so the script opens it for the LAN (sudo) and
# closes it again on exit. A rebuild or firewall restart also removes the rule.
#
# Submissions land in ./dev-share/, Signal messages are printed here and the
# robot check always passes (the widget still uses cap.toorren.net). index.html
# is re-read on every page load: edit it and press F5. Restart after Go changes.
# Put your own licensed LetterGothicStd.woff2 in ./dev-fonts/ (git-ignored) to see
# the headings as on the server; without it you see the sans-serif fallback.
set -euo pipefail
cd "$(dirname "$0")"

state=$(mktemp -d)
port=${FILEDROP_DEV_PORT:-18111}
bind=${FILEDROP_DEV_BIND:-0.0.0.0}
lan=$(ip -4 -o route get 1.1.1.1 2>/dev/null | sed -n 's/.* src \([0-9.]*\).*/\1/p') || true

fwrule=(nixos-fw -s 192.168.2.0/24 -p tcp --dport "$port" -j nixos-fw-accept)
if [[ $bind != 127.0.0.1 ]]; then
  sudo iptables -C "${fwrule[@]}" 2>/dev/null || sudo iptables -I "${fwrule[@]}"
fi

python3 -I dev-stub.py dev-share &
stub=$!
cleanup() {
  kill $stub 2>/dev/null || true
  if [[ $bind != 127.0.0.1 ]]; then
    while sudo iptables -D "${fwrule[@]}" 2>/dev/null; do :; done
  fi
}
trap cleanup EXIT
echo "Pagina: http://127.0.0.1:$port  (LAN: http://${lan:-<ip>}:$port)   inzendingen: $PWD/dev-share   stoppen: Ctrl-C"

env FILEDROP_PORT="$port" FILEDROP_ADDR="$bind" \
  FILEDROP_DEV_HTML="$PWD/index.html" \
  CAP_URL=http://127.0.0.1:18110/cap \
  CAP_WIDGET_URL=https://cap.toorren.net/92c7e198d7 \
  CAP_SECRET=dev \
  NEXTCLOUD_URL=http://127.0.0.1:18110 \
  NEXTCLOUD_SHARE_TOKEN=dev \
  SIGNAL_API=http://127.0.0.1:18110/signal \
  SIGNAL_SENDER=dev SIGNAL_RECIPIENT=dev \
  LARGE_FILE_CONTACT=eghmedia@evangelischegemeente.org \
  MAX_BYTES=$((25 * 1024 * 1024)) \
  LIMIT_PER_IP_HOUR=100 LIMIT_PER_IP_DAY=100 LIMIT_TOTAL_DAY=100 \
  LIMIT_BYTES_DAY=$((1024 * 1024 * 1024)) \
  STATE_DIRECTORY="$state" \
  FONT_DIR="$PWD/dev-fonts" \
  go run .
