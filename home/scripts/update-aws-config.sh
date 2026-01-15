#!/usr/bin/env bash
# Helper script to update AWS config after syncing managed accounts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
JSON_FILE="$REPO_ROOT/home/managed_service_accounts.json"

echo "==> Syncing AWS managed accounts..."
python3 "$SCRIPT_DIR/sync-aws-accounts.py"

echo "==> Copying JSON to repo for Nix..."
cp ~/.aws/managed_service_accounts.json "$REPO_ROOT/home/managed_service_accounts.json"

echo "==> Adding JSON file to git (force, despite .gitignore)..."
cd "$REPO_ROOT"
git add -f home/managed_service_accounts.json

echo "==> Rebuilding home-manager configuration..."
home-manager switch --flake .#wtoorren@linuxdesktop --extra-experimental-features nix-command --impure

echo "==> Done! AWS config updated with $(grep -c '^\[profile ' ~/.aws/config) profiles"
