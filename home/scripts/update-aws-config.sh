#!/usr/bin/env bash
# Helper script to update AWS config after syncing managed accounts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
JSON_FILE="$REPO_ROOT/home/managed_service_accounts.json"

# Pass through --login flag if provided
SYNC_FLAGS=""
if [[ "$1" == "--login" ]]; then
    SYNC_FLAGS="--login"
fi

echo "==> Syncing AWS managed accounts..."
python3 "$SCRIPT_DIR/sync-aws-accounts.py" $SYNC_FLAGS

echo "==> Rebuilding home-manager configuration..."
cd "$REPO_ROOT"
home-manager switch --flake .#wtoorren@linuxdesktop --extra-experimental-features nix-command --impure

echo "==> Done! AWS config updated with $(grep -c '^\[profile ' ~/.aws/config) profiles"
