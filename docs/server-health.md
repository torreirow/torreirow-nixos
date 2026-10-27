# Server Health Monitoring-dashboard (malandro)

Dashboard `modules/monitoring/grafana/dashboards/torreiro/server-health.json` (uid `server-health`).

## Last Boot Time

Bron is `node_boot_time_seconds{instance="localhost:9100"} * 1000` (node_exporter). De oude bron,
HA's `sensor.system_monitor_last_boot`, gaf "No data": die komt niet als waarde in Prometheus
(alleen `homeassistant_entity_available` e.d.).

## Systeeminfo (fastfetch)

- Module `modules/monitoring/prometheus/exporters/fastfetch.nix`: `fastfetch-textfile.service` +
  timer (2 min na boot, daarna elk uur) schrijft `fastfetch.prom` naar de node-exporter textfile
  collector (`/var/lib/prometheus-node-exporter-textfiles/`).
- Metric: `node_fastfetch_info{order="NN",key="…",value="…"} 1`, plus
  `node_fastfetch_last_success_timestamp_seconds`. De tabel sorteert op `order` en verbergt die kolom.
- "Reboot" is NixOS-specifiek: `REQUIRED (<onderdeel> gewijzigd)` als `/run/current-system` een
  andere kernel/initrd/kernel-modules heeft dan `/run/booted-system`. In de tabel rood/groen.
- "Kernel Latest" haalt de nieuwste versie in dezelfde branch op van kernel.org (curl, 5 s timeout).

### Valkuilen (gezien bij het bouwen, 2026-10-27)

- **`nix` moet op PATH** van de service: fastfetch telt pakketten via `nix-store`. Zonder dat valt
  de regel "Packages" stil weg (handmatig draaien werkt dan wél, want daar staat nix op PATH).
- **Regex voor stuurtekens**: gebruik `[[:cntrl:]]` in jq. Een `\u0000-\u001f`-reeks raakt door de
  escaping in Nix + shell + jq verminkt tot een range die cijfers en letters wegfiltert.

Handmatig testen zonder het echte bestand te overschrijven:

```bash
FASTFETCH_PROM_OUT=/tmp/ff.prom $(nix eval --raw .#nixosConfigurations.malandro.config.systemd.services.fastfetch-textfile.serviceConfig.ExecStart)
```
