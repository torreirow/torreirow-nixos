## Why

Er is geen zicht op of specifieke wifi-netwerken (SSID's) rond malandro nog uitzenden. Als een gevolgd accesspoint uitvalt of uit de lucht gaat, merk je dat nu pas als iemand klaagt. Door de zichtbaarheid van SSID's als Prometheus-metric te ontsluiten kan de bestaande monitoring-stack er automatisch op alerten via Telegram.

## What Changes

- Nieuwe NixOS-module die periodiek een wifi-scan draait op malandro (`wlp2s0`, NetworkManager) en per gevolgde SSID metrics schrijft naar de bestaande node-exporter textfile collector.
- De te volgen SSID's zijn flexibel opgeefbaar via een NixOS-optie (`services.wifi-ssid-monitor.watchSSIDs`, een list). Default: `[ "Peperbus" ]`.
- Metrics: `wifi_ssid_visible{ssid}` (0/1), `wifi_signal_percent{ssid}` (0–100) en `wifi_scan_last_success_timestamp_seconds` (staleness-signaal).
- Twee **generieke** Prometheus alert-regels die label-gewijs per SSID uitwaaieren, zodat het toevoegen van een SSID géén nieuwe alert-regel vereist:
  - `WifiSSIDWeg`: een gevolgde SSID is 5 min niet zichtbaar.
  - `WifiScanStale`: de scanner heeft >5 min geen update geschreven (nmcli/wifi kapot).
- Prometheus wordt uitgebreid met één extra ruleFile; Alertmanager blijft ongewijzigd (bestaande Telegram catch-all receiver vangt de alerts af).

## Capabilities

### New Capabilities
- `wifi-ssid-monitoring`: periodiek scannen van zichtbare wifi-SSID's, deze als Prometheus-metrics ontsluiten via de textfile collector, en er generiek op alerten.

### Modified Capabilities
<!-- Geen bestaande spec-capability wijzigt van requirements. -->

## Impact

- **Nieuwe module:** `modules/monitoring/prometheus/exporters/wifi-ssid.nix` (options + systemd service/timer + scan-script).
- **Import:** toegevoegd in `modules/monitoring/prometheus/default.nix`.
- **Nieuw alert-bestand:** `modules/monitoring/prometheus/alerts/wifi-alerts.yml`.
- **Prometheus:** `prometheus.nix` — `./alerts/wifi-alerts.yml` toevoegen aan `ruleFiles`.
- **Host:** malandro krijgt `services.wifi-ssid-monitor.enable = true;` met `watchSSIDs = [ "Peperbus" ]`.
- **Hergebruik (geen wijziging):** textfile collector dir `/var/lib/prometheus-node-exporter-textfiles`, node-exporter (`:9100`), Prometheus scrape, Alertmanager Telegram-receiver.
- **Afhankelijkheden:** `networkmanager` (`nmcli`) actief op de host, wifi-kaart aanwezig (geverifieerd: `wlp2s0`).
