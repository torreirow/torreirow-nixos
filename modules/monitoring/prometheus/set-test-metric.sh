#!/usr/bin/env bash
# Script om een test metric waarde te zetten voor Prometheus alerting test
#
# Gebruik:
#   ./set-test-metric.sh 150        # Zet waarde op 150 (triggert TestValueHigh alert)
#   ./set-test-metric.sh 5          # Zet waarde op 5 (triggert TestValueLow alert)
#   ./set-test-metric.sh 50         # Zet waarde op 50 (geen alerts)
#   ./set-test-metric.sh remove     # Verwijder de metric (triggert TestMetricMissing alert)

set -euo pipefail

TEXTFILE_DIR="/var/lib/prometheus-node-exporter-textfiles"
METRIC_FILE="${TEXTFILE_DIR}/test_metric.prom"

# Maak directory aan als die niet bestaat
mkdir -p "$TEXTFILE_DIR"

if [ $# -eq 0 ]; then
    echo "Gebruik: $0 <waarde|remove>"
    echo ""
    echo "Voorbeelden:"
    echo "  $0 150       # Triggert 'TestValueHigh' alert (waarde > 100)"
    echo "  $0 5         # Triggert 'TestValueLow' alert (waarde < 10)"
    echo "  $0 50        # Geen alerts (10 <= waarde <= 100)"
    echo "  $0 remove    # Triggert 'TestMetricMissing' alert"
    echo ""
    if [ -f "$METRIC_FILE" ]; then
        echo "Huidige waarde:"
        cat "$METRIC_FILE"
    else
        echo "Geen metric bestand gevonden: $METRIC_FILE"
    fi
    exit 1
fi

if [ "$1" = "remove" ]; then
    if [ -f "$METRIC_FILE" ]; then
        rm -f "$METRIC_FILE"
        echo "✓ Metric verwijderd: $METRIC_FILE"
        echo "  → Na ~1 minuut triggert de 'TestMetricMissing' alert"
    else
        echo "⚠ Metric bestand bestaat niet: $METRIC_FILE"
    fi
    exit 0
fi

# Valideer dat het een nummer is
if ! [[ "$1" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "✗ Fout: '$1' is geen geldige numerieke waarde"
    exit 1
fi

VALUE="$1"

# Schrijf de metric naar het textfile
cat > "$METRIC_FILE.tmp" <<EOF
# HELP test_metric_value Test metric voor alert testing
# TYPE test_metric_value gauge
test_metric_value $VALUE
EOF

# Atomic rename (zodat Prometheus nooit een half-geschreven bestand leest)
mv "$METRIC_FILE.tmp" "$METRIC_FILE"

echo "✓ Test metric gezet: test_metric_value = $VALUE"
echo "  Bestand: $METRIC_FILE"
echo ""

# Geef feedback over welke alerts getriggerd worden
if (( $(echo "$VALUE > 100" | bc -l) )); then
    echo "  → Triggert 'TestValueHigh' alert (waarde > 100)"
elif (( $(echo "$VALUE < 10" | bc -l) )); then
    echo "  → Triggert 'TestValueLow' alert (waarde < 10)"
else
    echo "  → Geen alerts (waarde tussen 10 en 100)"
fi

echo ""
echo "Check de alert status op:"
echo "  - Prometheus: https://prometheus.toorren.net/alerts"
echo "  - Alertmanager: https://alertmanager.toorren.net/"
echo ""
echo "Je zou binnen 30-60 seconden een Telegram notificatie moeten ontvangen."
