## Context

De monitoring-stack op malandro (Prometheus, node-exporter met textfile collector, Alertmanager met Telegram) is al operationeel. malandro heeft een wifi-kaart (`wlp2s0`, geverifieerd) en draait NetworkManager. De textfile collector directory `/var/lib/prometheus-node-exporter-textfiles` (mode 1777) bestaat al, node-exporter heeft `enabledCollectors = ["textfile"]`, en `ruleFiles` in `prometheus.nix` is uitbreidbaar via `lib.mkBefore`. Er zijn al bestaande patronen voor textfile-metrics (`set-test-metric.sh`) en voor staleness-alerts (`SpeedtestStale`, `MagisterSyncHeartbeatMissing`).

Deze change voegt daar een wifi-SSID-monitor aan toe met minimale nieuwe infrastructuur: hij hergebruikt de complete bestaande scrape- en alert-keten.

## Goals / Non-Goals

**Goals:**
- Zichtbaarheid en signaalsterkte van een flexibele lijst SSID's als Prometheus-metrics ontsluiten.
- Alerting die generiek is: een SSID toevoegen vereist alléén een wijziging aan `watchSSIDs`, geen script- of alert-wijziging.
- Zo min mogelijk resources: geen langdraaiend proces, geen extra open poort.
- Detectie van een kapotte scanner (staleness), zodat storingen niet stilzwijgend leiden tot verouderde data.

**Non-Goals:**
- Geen wijziging aan de Alertmanager-config (receivers/routes/grouping blijven zoals ze zijn).
- Geen rogue-AP / security-detectie of historische SSID-survey buiten de `watchSSIDs`-lijst.
- Geen monitoring op andere hosts dan malandro (lobos is buiten scope).
- Geen eigen HTTP-exporter of pushgateway.

## Decisions

### Textfile collector i.p.v. eigen exporter
Metrics worden weggeschreven als `.prom`-bestand in de bestaande textfile collector directory. node-exporter serveert ze automatisch; Prometheus scrapet ze al.
- **Waarom:** nul nieuwe scrape-config, nul nieuwe poort, nul firewall-wijziging. Sluit aan bij het bestaande `set-test-metric.sh`-patroon.
- **Alternatief:** eigen HTTP-exporter (zoals vulnix) — verworpen: vereist poort, scrape-config en een langdraaiend proces met constant geheugengebruik.

### Bash-script + systemd timer i.p.v. Python-daemon
Een kort bash-script gestart door een systemd timer (default elke 30s), niet een persistent proces.
- **Waarom:** de dominante kostenpost is de kernel wifi-scan (`--rescan yes`, ~1–3s), taal-onafhankelijk. Bash-opstart (~2–5ms) is per run goedkoper dan Python-interpreter-opstart (~30–50ms), en tussen runs is het verbruik nul. Een persistent Python-exporter zou 24/7 ~15–30MB RAM vasthouden.
- **Alternatief:** Python — verworpen voor dit geval; de parsing is triviaal (splitsen op `:`) en rechtvaardigt de zwaardere runtime niet.

### Datamodel: info-metric + numerieke metric + staleness-timestamp
- `wifi_ssid_visible{ssid}` (0/1) — voor élke SSID in `watchSSIDs` altijd geschreven, zodat de timeseries bestaat en `== 0` betrouwbaar werkt.
- `wifi_signal_percent{ssid}` — alleen wanneer zichtbaar; sterkste signaal (`max`) over alle APs met die SSID.
- `wifi_scan_last_success_timestamp_seconds` — alleen bij volledig geslaagde run (`set -euo pipefail` + atomic `mv`).
- **Waarom:** SSID is een string en kan niet als metric-waarde; het label-patroon is de standaard. De altijd-aanwezige `visible`-regel voorkomt het "metric bestaat nog niet"-gat.

### Generieke alert-expressies
`expr: wifi_ssid_visible == 0` (zonder ssid-filter) waaiert automatisch uit per timeseries; de SSID komt via `{{ $labels.ssid }}` in de annotatie.
- **Waarom:** voldoet aan de kerneis — een SSID toevoegen vereist geen alert-wijziging.
- **Alternatief:** per-SSID hardcoded regels — verworpen: schaalt niet en vereist onderhoud per netwerk.

### Fixed-string matching en max-signaal
Parsing matcht SSID's als letterlijke strings (geen regex-grep) en neemt het sterkste signaal bij dubbele APs.
- **Waarom:** SSID's kunnen regex-metatekens bevatten; `grep -m1` zou een willekeurige (niet de sterkste) AP pakken.

## Risks / Trade-offs

- **wlp2s0 is `disconnected`** → scannen kan zonder associatie, dus geen blokker. Mocht de kaart later voor iets anders in gebruik zijn, dan kan een `--rescan yes` kort met de actieve verbinding concurreren. → Mitigatie: interval niet te laag zetten (30s default is ruim).
- **Scan-frequentie vs. radiobelasting** → elke 30s een actieve scan kost radiotijd. → Mitigatie: interval is een NixOS-optie; verhoog indien nodig.
- **Alertmanager `repeat_interval = 8760h`** → een alert gaat effectief één keer naar Telegram tot resolved; geen herhaalde reminders. → Bewuste acceptatie; geen wijziging aan de gedeelde Alertmanager-config.
- **`group_by = ["alertname"]`** → meerdere tegelijk wegvallende SSID's komen in één Telegram-bericht (met meerdere ssid-labels). → Acceptabel; per-SSID losse berichten zouden de gedeelde config raken.
- **NetworkManager-afhankelijkheid** → als NM niet draait faalt `nmcli`. → De `WifiScanStale`-alert vangt dit af (timestamp veroudert).

## Migration Plan

1. Module + alert-bestand toevoegen, import + ruleFile-regel bijwerken, `services.wifi-ssid-monitor` inschakelen op malandro met `watchSSIDs = [ "Peperbus" ]`.
2. `sudo nixos-rebuild switch --flake .#malandro`.
3. Verifiëren: `cat /var/lib/prometheus-node-exporter-textfiles/wifi_scan.prom`, metric op `:9100/metrics`, en de regels in Prometheus (`/rules`) / Alertmanager.
4. **Rollback:** `services.wifi-ssid-monitor.enable = false` (of de commit terugdraaien) + rebuild. Geen gedeelde state wordt gewijzigd; de textfile verdwijnt en de timeseries worden stale/absent.

## Open Questions

- Wil je een signaalsterkte-drempel-alert (bijv. `wifi_signal_percent < 30`)? Nu bewust weggelaten (alleen zichtbaarheid + staleness gekozen), maar de metric is beschikbaar.
- Interval van 30s akkoord, of liever rustiger (bijv. 60s) om radiobelasting te beperken?
