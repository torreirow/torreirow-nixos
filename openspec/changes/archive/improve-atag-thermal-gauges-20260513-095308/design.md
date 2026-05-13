## Context

The ATAG thermal dashboard currently uses `deriv()` over 15-minute and 30-minute windows to calculate temperature change rates. The Heating Rate gauge can show negative values when cooling occurs, which displays as RED and creates confusion—users expect RED to mean "something is wrong" rather than "normal nighttime cooling."

The current threshold model also rewards speed over efficiency: fast heating (>1.5°C/h) shows as GREEN, but this often indicates excessive boiler cycling and poor efficiency.

## Goals / Non-Goals

**Goals:**
- Separate heating and cooling into distinct, semantically clear metrics
- Use efficiency-based thresholds that reflect HVAC best practices
- Eliminate negative value display confusion
- Maintain existing time-series panels (Panel 5) that show historical rate changes

**Non-Goals:**
- Changing the underlying Prometheus metrics or Home Assistant configuration
- Modifying other dashboard panels beyond the two rate gauges
- Adding new data sources or sensors

## Decisions

### Decision 1: Use clamp_min()/clamp_max() to separate heating from cooling

**Choice:** Use `clamp_min(deriv(...) * 3600, 0)` for heating and `abs(clamp_max(deriv(...) * 3600, 0))` for cooling

**Rationale:**
- `clamp_min()` clamps minimum value to 0, so negative (cooling) values become 0
- `clamp_max()` clamps maximum value to 0, so positive (heating) values become 0, then `abs()` gives magnitude
- Mathematically separates positive (heating) from negative (cooling) derivatives
- Grafana gauges display 0 when the opposite condition occurs (clean, not N/A)
- No complex conditional logic or transforms needed
- Works with existing `deriv()` calculations

**Alternatives considered:**
- `max()`/`min()` functions: These are aggregation operators in PromQL, not scalar comparisons - don't work for this use case
- Separate queries with `> 0` and `< 0` filters: Would require more complex PromQL and could result in empty results
- Grafana transforms: More fragile, harder to maintain, less portable

### Decision 2: Keep 15m window for heating, 30m window for cooling

**Choice:** Maintain current window sizes (15m heating, 30m cooling)

**Rationale:**
- Heating response is faster and benefits from shorter window (captures boiler starts quickly)
- Cooling is slower and more stable, 30m window reduces noise
- These windows have already been tuned to the ATAG system's behavior
- Asymmetry reflects real thermal physics (heat gain ≠ heat loss characteristics)

**Alternatives considered:**
- Unified 15m or 30m window: Would lose either heating responsiveness or cooling stability

### Decision 3: Efficiency-focused threshold model

**Choice:**
- Heating: 0-0.2 stable/gray, 0.2-0.8 optimal/green, 0.8-1.2 active/yellow, >1.2 inefficient/red
- Cooling: 0-0.4 minimal/green, 0.4-0.8 normal/yellow, >0.8 fast/red

**Rationale:**
- Based on typical residential HVAC efficiency curves
- 0.2-0.8°C/h heating range minimizes boiler cycling while maintaining comfort
- >1.2°C/h heating indicates aggressive cycling (see Panel 6: Brander Cycling)
- Cooling thresholds are more lenient because heat loss is passive and less controllable
- Aligns with Panel 7 (Target Tracking) expectations: 1-2°C delta with 0.5°C/h rate = reasonable catchup time

**Alternatives considered:**
- Keep speed-based thresholds: Doesn't align with efficiency goals
- Make thresholds symmetric: Doesn't reflect asymmetric thermal physics

### Decision 4: Update gauge visualization only, keep time-series panel

**Choice:** Modify Panel 2 (Heating Rate gauge) and Panel 3 (Cooling Rate gauge) only. Leave Panel 5 (Temperature Change Rate time-series) unchanged.

**Rationale:**
- Panel 5 shows historical trends and benefits from seeing both positive and negative values
- Bar chart format clearly distinguishes cooling (below axis) from heating (above axis)
- Gauges show instantaneous state and need semantic clarity; time-series shows context

**Alternatives considered:**
- Apply same logic to Panel 5: Would hide cooling periods entirely, losing valuable historical context

## Risks / Trade-offs

**Risk: Gauges showing 0 might be interpreted as "no data"**
- Mitigation: This is semantic correctness—0 means "not heating" or "not cooling", which is accurate

**Risk: Users accustomed to old thresholds might be confused initially**
- Mitigation: Thresholds are more intuitive (green = good, red = excessive), should feel natural

**Trade-off: Heating and cooling gauges won't sum to total rate**
- This is intentional—they're distinct operational metrics, not components of a total

**Risk: 15m/30m windows might not suit all scenarios**
- Mitigation: These are already in production and tuned to the system. Can adjust if needed based on operational data.

## Migration Plan

1. Update Panel 2 and Panel 3 in `atag-thermal-dashboard.json`
2. Deploy via NixOS rebuild (Grafana dashboards are provisioned from this file)
3. No rollback complexity—dashboard changes are instant and non-destructive
4. If thresholds need adjustment, can be iterated quickly

## Open Questions

None—this is a straightforward dashboard visualization change with no system dependencies.
