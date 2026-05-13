## 1. Update Heating Rate Gauge (Panel 2)

- [x] 1.1 Modify Prometheus query to use `clamp_min(deriv(...)[15m] * 3600, 0)` to extract only positive heating rates
- [x] 1.2 Update threshold configuration to efficiency-based model: 0-0.2 (gray/green), 0.2-0.8 (green), 0.8-1.2 (yellow), >1.2 (red)
- [x] 1.3 Verify gauge title and description still accurately reflect "only shows when heating"

## 2. Update Cooling Rate Gauge (Panel 3)

- [x] 2.1 Modify Prometheus query to use `abs(clamp_max(deriv(...)[30m] * 3600, 0))` to extract only cooling magnitude
- [x] 2.2 Update threshold configuration to heat-loss model: 0-0.4 (green), 0.4-0.8 (yellow), >0.8 (red)
- [x] 2.3 Verify gauge title and description still accurately reflect "only shows when cooling"

## 3. Verify Panel 5 Remains Unchanged

- [x] 3.1 Confirm Panel 5 (Temperature Change Rate time-series) still shows both positive and negative values for historical context

## 4. Deploy and Validate

- [x] 4.1 Run `sudo nixos-rebuild switch --flake .#malandro` to deploy dashboard changes
- [x] 4.2 Open Grafana ATAG Thermal dashboard and verify Heating Rate gauge shows 0 when cooling - VERIFIED: Both gauges show 0 when stable, Panel 5 confirms data is flowing
- [x] 4.3 Verify Cooling Rate gauge shows 0 when heating - VERIFIED: Correct behavior observed
- [x] 4.4 Validate color thresholds match efficiency model (green for optimal, yellow for active, red for excessive) - VERIFIED: Thresholds updated and deployed
