## 1. Exporter-module

- [x] 1.1 Maak `modules/monitoring/prometheus/exporters/wifi-ssid.nix` met `options.services.wifi-ssid-monitor`: `enable` (mkEnableOption), `watchSSIDs` (listOf str, default `[ "Peperbus" ]`), `interval` (str, default `"30s"`)
- [x] 1.2 Schrijf het scan-script (bash): `nmcli -t -f SSID,SIGNAL dev wifi list --rescan yes`, per SSID uit `watchSSIDs` een `wifi_ssid_visible{ssid}` (0/1) en bij zichtbaarheid `wifi_signal_percent{ssid}` (max-signaal); fixed-string match, `set -euo pipefail`
- [x] 1.3 Voeg `wifi_scan_last_success_timestamp_seconds` toe aan het einde van het script (alleen bij geslaagde run)
- [x] 1.4 Schrijf atomair naar `/var/lib/prometheus-node-exporter-textfiles/wifi_scan.prom` (`.tmp` + `mv`)
- [x] 1.5 Genereer de bash `WATCH`-array uit `cfg.watchSSIDs` via `lib.escapeShellArg` (geen hardcoded SSID's in het script)
- [x] 1.6 Definieer `systemd.services.wifi-ssid-scan` (oneshot, draait het script, `path`/`ExecStart` met `networkmanager`/`nmcli` + `coreutils`) en `systemd.timers.wifi-ssid-scan` met `OnUnitActiveSec = cfg.interval` + `OnBootSec`, alles onder `lib.mkIf cfg.enable`

## 2. Prometheus-integratie

- [x] 2.1 Importeer `./exporters/wifi-ssid.nix` in `modules/monitoring/prometheus/default.nix`
- [x] 2.2 Maak `modules/monitoring/prometheus/alerts/wifi-alerts.yml` met groep `wifi` en de generieke regels `WifiSSIDWeg` (`wifi_ssid_visible == 0`, `for: 5m`, annotatie met `{{ $labels.ssid }}`) en `WifiScanStale` (`time() - wifi_scan_last_success_timestamp_seconds > 300`, `for: 5m`)
- [x] 2.3 Voeg `./alerts/wifi-alerts.yml` toe aan `ruleFiles` in `prometheus.nix` (bestaande `lib.mkBefore`-lijst)

## 3. Host-activatie

- [x] 3.1 Zet `services.wifi-ssid-monitor.enable = true;` met `watchSSIDs = [ "Peperbus" ];` op malandro (via de monitoring-module of `hosts/malandro/configuration.nix`)

## 4. Build & verificatie

- [x] 4.1 `sudo nixos-rebuild switch --flake .#malandro` slaagt zonder evaluatiefouten
- [x] 4.2 Verifieer `systemctl status wifi-ssid-scan.timer` actief en `journalctl -u wifi-ssid-scan.service` toont een geslaagde run
- [x] 4.3 Verifieer `wifi_scan.prom` bevat `wifi_ssid_visible{ssid="Peperbus"}`, `wifi_scan_last_success_timestamp_seconds`, en de metric verschijnt op `:9100/metrics`
- [x] 4.4 Verifieer in Prometheus `/rules` dat `WifiSSIDWeg` en `WifiScanStale` geladen zijn (geen syntaxfout), en dat Alertmanager de alerts zou ontvangen via de bestaande Telegram-receiver
