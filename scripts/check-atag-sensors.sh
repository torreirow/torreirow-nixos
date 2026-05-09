#!/usr/bin/env bash
# Script to check all ATAG One sensors in Home Assistant

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

HA_URL="http://localhost:8123"
HA_TOKEN_FILE="/var/lib/prometheus/homeassistant-bearer-token"

echo "=== ATAG One Sensor Check ==="
echo ""

# Read bearer token (remove "Bearer " prefix if present)
if [ -f "$HA_TOKEN_FILE" ]; then
    TOKEN=$(cat "$HA_TOKEN_FILE" | sed 's/^Bearer //')
else
    echo -e "${RED}Error: Token file not found at $HA_TOKEN_FILE${NC}"
    exit 1
fi

echo "1. Fetching all ATAG sensors from Home Assistant..."
echo ""

# Get all entities that contain "atag" (case insensitive)
curl -s -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     "$HA_URL/api/states" | \
jq -r '.[] | select(.entity_id | ascii_downcase | contains("atag")) |
    {
        entity_id: .entity_id,
        state: .state,
        unit: .attributes.unit_of_measurement // "none",
        friendly_name: .attributes.friendly_name,
        disabled: (.attributes.disabled // false)
    } |
    "\(.entity_id)\t\(.state)\t\(.unit)\t\(.friendly_name)"' | \
sort | column -t -s $'\t'

echo ""
echo "2. Checking Prometheus metrics for ATAG sensors..."
echo ""

# Check which ATAG metrics are available in Prometheus
curl -s 'http://localhost:9090/api/v1/label/entity/values' | \
jq -r '.data[]' | grep -i atag | sort

echo ""
echo "3. Specific check for cv_retour_temp..."
echo ""

# Check if cv_retour_temp exists in HA
RETOUR_EXISTS=$(curl -s -H "Authorization: Bearer $TOKEN" \
     "$HA_URL/api/states/sensor.atag_one_cv_retour_temp" | jq -r '.entity_id // "NOT_FOUND"')

if [ "$RETOUR_EXISTS" = "NOT_FOUND" ]; then
    echo -e "${RED}✗ sensor.atag_one_cv_retour_temp NOT FOUND in Home Assistant${NC}"
    echo ""
    echo "Searching for similar sensors (return/retour)..."
    curl -s -H "Authorization: Bearer $TOKEN" "$HA_URL/api/states" | \
    jq -r '.[] | select(.entity_id | ascii_downcase | contains("atag")) |
        select(.entity_id | ascii_downcase | contains("return") or contains("retour")) |
        .entity_id'
else
    RETOUR_STATE=$(curl -s -H "Authorization: Bearer $TOKEN" \
         "$HA_URL/api/states/sensor.atag_one_cv_retour_temp" | jq -r '.state')
    RETOUR_UNIT=$(curl -s -H "Authorization: Bearer $TOKEN" \
         "$HA_URL/api/states/sensor.atag_one_cv_retour_temp" | jq -r '.attributes.unit_of_measurement // "none"')

    echo -e "${GREEN}✓ sensor.atag_one_cv_retour_temp EXISTS${NC}"
    echo "  State: $RETOUR_STATE $RETOUR_UNIT"

    # Check if it's in Prometheus
    PROM_CHECK=$(curl -s 'http://localhost:9090/api/v1/label/entity/values' | \
        jq -r '.data[]' | grep -c "sensor.atag_one_cv_retour_temp" || echo "0")

    if [ "$PROM_CHECK" -eq 0 ]; then
        echo -e "  ${RED}✗ NOT exported to Prometheus${NC}"
        echo ""
        echo "This sensor needs to be added to the Prometheus filter in Home Assistant."
        echo "Edit /var/lib/homeassistant/configuration.yaml and add under prometheus.filter:"
        echo ""
        echo "    include_entity_globs:"
        echo "      - sensor.atag_one_*"
        echo ""
        echo "Then restart Home Assistant: docker restart homeassistant"
    else
        echo -e "  ${GREEN}✓ Exported to Prometheus${NC}"
    fi
fi

echo ""
echo "4. Checking ch_return_temperature (official integration name)..."
echo ""

# Check official integration sensor name
CH_RETURN=$(curl -s -H "Authorization: Bearer $TOKEN" \
     "$HA_URL/api/states/sensor.atag_one_ch_return_temperature" | jq -r '.entity_id // "NOT_FOUND"')

if [ "$CH_RETURN" = "NOT_FOUND" ]; then
    echo -e "${YELLOW}sensor.atag_one_ch_return_temperature NOT FOUND${NC}"
else
    echo -e "${GREEN}✓ sensor.atag_one_ch_return_temperature EXISTS${NC}"
    STATE=$(curl -s -H "Authorization: Bearer $TOKEN" \
         "$HA_URL/api/states/sensor.atag_one_ch_return_temperature" | jq -r '.state')
    UNIT=$(curl -s -H "Authorization: Bearer $TOKEN" \
         "$HA_URL/api/states/sensor.atag_one_ch_return_temperature" | jq -r '.attributes.unit_of_measurement // "none"')
    echo "  State: $STATE $UNIT"
fi

echo ""
echo "Done!"
