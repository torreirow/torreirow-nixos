#!/usr/bin/env bash
# Run the upload page locally: http://127.0.0.1:18111
#
# Submissions land in ./dev-share/, Signal messages are printed here and the
# robot check always passes (the widget still uses cap.toorren.net). index.html
# is re-read on every page load: edit it and press F5. Restart after Go changes.
set -euo pipefail
cd "$(dirname "$0")"

python3 -I dev-stub.py dev-share &
stub=$!
trap 'kill $stub 2>/dev/null' EXIT

state=$(mktemp -d)
echo "Pagina: http://127.0.0.1:18111   inzendingen: $PWD/dev-share   stoppen: Ctrl-C"

env FILEDROP_PORT=18111 \
  FILEDROP_DEV_HTML="$PWD/index.html" \
  CAP_URL=http://127.0.0.1:18110/cap \
  CAP_WIDGET_URL=https://cap.toorren.net/92c7e198d7 \
  CAP_SECRET=dev \
  NEXTCLOUD_URL=http://127.0.0.1:18110 \
  NEXTCLOUD_SHARE_TOKEN=dev \
  SIGNAL_API=http://127.0.0.1:18110/signal \
  SIGNAL_SENDER=dev SIGNAL_RECIPIENT=dev \
  LARGE_FILE_CONTACT=taakgroepbeeldengeluid@evangelischegemeente.org \
  MAX_BYTES=$((25 * 1024 * 1024)) \
  LIMIT_PER_IP_HOUR=100 LIMIT_PER_IP_DAY=100 LIMIT_TOTAL_DAY=100 \
  LIMIT_BYTES_DAY=$((1024 * 1024 * 1024)) \
  STATE_DIRECTORY="$state" \
  go run .
