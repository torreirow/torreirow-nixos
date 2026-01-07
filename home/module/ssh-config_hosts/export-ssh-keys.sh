#!/usr/bin/env bash

# Script to export SSH public keys from rbw SSH agent to .pub files
# Automatically matches keys by comparing fingerprints from rbw with SSH agent
#
# Part of: home/module/ssh-config_hosts (NixOS Home Manager module)
# This script is installed to ~/bin/export-ssh-keys.sh via default.nix
#
# Version: 202601071425

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Output directory for SSH keys (can be overridden by environment variable)
OUTPUT_DIR="${RBW_SSH_KEYS_DIR:-$HOME/.ssh/rbw-keys}"

echo "=== RBW SSH Key Export Tool ==="
echo

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed${NC}"
    echo -e "${YELLOW}Install jq: sudo apt install jq (Debian/Ubuntu) or brew install jq (macOS)${NC}"
    exit 1
fi

# Check if rbw is available
if ! command -v rbw &> /dev/null; then
    echo -e "${RED}Error: rbw command not found${NC}"
    exit 1
fi

# Check if SSH agent is running
if ! ssh-add -l &> /dev/null; then
    echo -e "${RED}Error: No SSH agent running or no keys loaded${NC}"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"
echo -e "${BLUE}Output directory: $OUTPUT_DIR${NC}"
echo

# Get all keys from SSH agent
echo "Fetching keys from SSH agent..."
mapfile -t agent_keys < <(ssh-add -L)

if [ ${#agent_keys[@]} -eq 0 ]; then
    echo -e "${RED}No keys found in SSH agent${NC}"
    exit 1
fi

echo -e "${GREEN}Found ${#agent_keys[@]} key(s) in SSH agent${NC}"
echo

# Calculate fingerprints for agent keys
echo "Calculating fingerprints for SSH agent keys..."
declare -A agent_fingerprints
declare -A agent_key_types
for i in "${!agent_keys[@]}"; do
    key="${agent_keys[$i]}"
    tmpfile="/tmp/rbw-export-key-$i.pub"
    echo "$key" > "$tmpfile"
    fp=$(ssh-keygen -lf "$tmpfile" 2>/dev/null | awk '{print $2}')
    rm -f "$tmpfile"
    agent_fingerprints[$i]="$fp"
    agent_key_types[$i]=$(echo "$key" | awk '{print $1}')
    echo "  Key $((i+1)): $fp (${agent_key_types[$i]})"
done
echo

# Fetch item list from rbw and filter for ssh-keys folder
echo "Fetching SSH key items from rbw..."
echo

rbw_list_json=$(rbw list --raw 2>/dev/null)

if [ -z "$rbw_list_json" ]; then
    echo -e "${RED}Error: Could not fetch items from rbw${NC}"
    exit 1
fi

# Extract IDs of items in ssh-keys folder
mapfile -t ssh_key_ids < <(echo "$rbw_list_json" | jq -r '.[] | select(.folder == "ssh-keys") | .id')

if [ ${#ssh_key_ids[@]} -eq 0 ]; then
    echo -e "${YELLOW}Warning: No items found in rbw ssh-keys folder${NC}"
    exit 1
fi

echo -e "${GREEN}Found ${#ssh_key_ids[@]} item(s) in ssh-keys folder${NC}"
echo

# Fetch full data for each SSH key item
echo "Fetching fingerprints from rbw SSH keys..."
declare -A rbw_fingerprints
declare -A rbw_names
declare -A rbw_public_keys

for id in "${ssh_key_ids[@]}"; do
    item_json=$(rbw get "$id" --raw 2>/dev/null || true)

    if [ -z "$item_json" ]; then
        echo -e "${YELLOW}  Warning: Could not retrieve item $id${NC}"
        continue
    fi

    # Extract name, fingerprint, and public_key
    name=$(echo "$item_json" | jq -r '.name // empty')
    fingerprint=$(echo "$item_json" | jq -r '.data.fingerprint // empty')
    public_key=$(echo "$item_json" | jq -r '.data.public_key // empty')

    if [ -n "$fingerprint" ] && [ -n "$name" ]; then
        rbw_fingerprints["$fingerprint"]="$name"
        rbw_names["$name"]="$fingerprint"
        rbw_public_keys["$name"]="$public_key"
        echo "  ✓ $name → $fingerprint"
    else
        if [ -n "$name" ]; then
            echo -e "${YELLOW}  ⚠ $name: No fingerprint field${NC}"
        fi
    fi
done

echo

# Check if we found any keys with fingerprints
set +u
fp_count="${#rbw_fingerprints[@]}"
set -u

if [ "$fp_count" -eq 0 ]; then
    echo -e "${RED}Error: No SSH keys with fingerprints found in rbw ssh-keys folder${NC}"
    echo -e "${YELLOW}Make sure your SSH keys in rbw have a fingerprint field${NC}"
    exit 1
fi

echo -e "${GREEN}Successfully retrieved $fp_count SSH key(s) with fingerprints from rbw${NC}"
echo

# Match and export keys
echo "========================================="
echo "Matching and exporting keys..."
echo "========================================="
echo

matched_count=0
unmatched_count=0

for i in "${!agent_keys[@]}"; do
    key="${agent_keys[$i]}"
    fp="${agent_fingerprints[$i]}"
    key_type="${agent_key_types[$i]}"

    echo "----------------------------------------"
    echo "Key $((i+1))/${#agent_keys[@]}"
    echo "Type: $key_type"
    echo "Fingerprint: $fp"
    echo

    # Try to find matching rbw item
    if [ -n "${rbw_fingerprints[$fp]:-}" ]; then
        rbw_name="${rbw_fingerprints[$fp]}"
        echo -e "${GREEN}✓ Matched with rbw item: $rbw_name${NC}"

        # Generate private key file (empty, as we use SSH agent)
        private_key_file="$OUTPUT_DIR/${rbw_name}"
        touch "$private_key_file"
        chmod 600 "$private_key_file"

        # Generate .pub file with public key from SSH agent
        pub_file="$OUTPUT_DIR/${rbw_name}.pub"
        echo "$key" > "$pub_file"
        chmod 644 "$pub_file"

        echo -e "${GREEN}✓ Created: $pub_file${NC}"
        echo -e "${BLUE}  (Private key placeholder: $private_key_file)${NC}"

        matched_count=$((matched_count + 1))
    else
        echo -e "${YELLOW}⚠ Warning: No matching item found in rbw ssh-keys folder${NC}"
        echo -e "${YELLOW}  This key is loaded in SSH agent but not tracked in rbw${NC}"
        echo -e "${YELLOW}  Fingerprint: $fp${NC}"

        unmatched_count=$((unmatched_count + 1))
    fi
    echo
done

echo "========================================="
echo -e "${GREEN}Export complete!${NC}"
echo
echo "Summary:"
echo "  Matched and exported: $matched_count key(s)"
if [ $unmatched_count -gt 0 ]; then
    echo -e "  ${YELLOW}Unmatched (not in rbw): $unmatched_count key(s)${NC}"
fi
echo

echo "Generated files in $OUTPUT_DIR:"
ls -lh "$OUTPUT_DIR"/*.pub 2>/dev/null || echo "No .pub files found"
