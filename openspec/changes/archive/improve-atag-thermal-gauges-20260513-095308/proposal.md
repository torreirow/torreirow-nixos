## Why

The current ATAG thermal dashboard shows confusing feedback when the room is cooling. The "Heating Rate" gauge displays negative values (e.g., -0.579°C/h) as RED, which feels like an error state rather than the normal cooling behavior. The thresholds also don't reflect efficiency best practices—they reward fast heating rather than optimal thermal behavior.

## What Changes

- Split heating and cooling into semantically clear gauges that only show relevant values
- Heating Rate gauge: Only shows positive values when actively heating (0 = not heating)
- Cooling Rate gauge: Only shows magnitude when room is losing heat
- Update thresholds to efficiency-focused model:
  - Heating: 0-0.2°C/h stable (green), 0.2-0.8°C/h healthy (green), 0.8-1.2°C/h active (yellow), >1.2°C/h aggressive/inefficient (red)
  - Cooling: 0-0.4°C/h minimal loss (green), 0.4-0.8°C/h normal (yellow), >0.8°C/h fast loss (red)
- Modify Prometheus queries to use `max()`/`min()` to separate heating from cooling

## Capabilities

### New Capabilities
- `thermal-rate-gauges`: Display heating and cooling rates with efficiency-based thresholds that provide clear operational feedback

### Modified Capabilities
<!-- No existing specs are being modified, this is a net-new visualization improvement -->

## Impact

- **Affected files**: `modules/monitoring/grafana/dashboards/torreiro/atag-thermal-dashboard.json`
- **Visualization change**: Panel 2 (Heating Rate) and Panel 3 (Cooling Rate) will show different values and colors
- **No breaking changes**: This is a dashboard-only change, no APIs or integrations affected
- **User experience**: Clearer interpretation of thermal behavior, less confusion about "red = bad" when cooling is expected
