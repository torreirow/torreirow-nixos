# wifi-ssid-monitoring Specification

## Purpose

Deze capability monitort de zichtbaarheid en signaalsterkte van een declaratief opgegeven lijst wifi-SSID's via een periodieke NetworkManager-scan, exporteert het resultaat als Prometheus-metrics via de node-exporter textfile collector, en levert generieke, label-gewijze alerting zodat het wegvallen van een SSID of een kapotte scanner tijdig gedetecteerd wordt.

## Requirements

### Requirement: Configurable list of monitored SSIDs
De module SHALL een NixOS-optie `services.wifi-ssid-monitor.watchSSIDs` bieden van het type `listOf str`, waarmee de te monitoren SSID's declaratief worden opgegeven. De module SHALL voor elke opgegeven SSID metrics produceren, zonder dat het script of de alert-regels gewijzigd hoeven te worden bij het toevoegen of verwijderen van een SSID.

#### Scenario: SSID toevoegen aan de lijst
- **WHEN** een operator `watchSSIDs` uitbreidt met een nieuwe SSID en `nixos-rebuild switch` draait
- **THEN** produceert de eerstvolgende scan metrics met die SSID als `ssid`-label, zonder wijziging aan het scan-script of de alert-regels

#### Scenario: SSID verwijderen uit de lijst
- **WHEN** een operator een SSID uit `watchSSIDs` verwijdert en herbouwt
- **THEN** schrijft de scan geen metrics meer voor die SSID en verdwijnt de bijbehorende timeseries, waardoor een eventueel lopende alert vanzelf resolvet

#### Scenario: Enable-flag uit
- **WHEN** `services.wifi-ssid-monitor.enable = false` (of niet gezet)
- **THEN** worden er geen systemd-units, timer of scan-script geactiveerd

### Requirement: Periodieke wifi-scan als exporter
De module SHALL periodiek een wifi-scan uitvoeren via NetworkManager (`nmcli ... dev wifi list --rescan yes`) op een configureerbaar interval (default 30s) en het resultaat wegschrijven naar de node-exporter textfile collector directory (`/var/lib/prometheus-node-exporter-textfiles/wifi_scan.prom`). Het wegschrijven SHALL atomair gebeuren (schrijf naar een tijdelijk bestand en `mv` naar de definitieve naam).

#### Scenario: Geslaagde scan schrijft metrics
- **WHEN** de timer de scan-service start en `nmcli` een scanresultaat teruggeeft
- **THEN** bevat `wifi_scan.prom` voor elke gevolgde SSID een `wifi_ssid_visible{ssid=...}` regel, en wordt het bestand atomair vervangen

#### Scenario: Node-exporter pikt de metrics op
- **WHEN** de textfile collector de nieuwe `wifi_scan.prom` inleest
- **THEN** zijn de metrics zichtbaar op de node-exporter endpoint (`:9100/metrics`) en scrapet Prometheus ze bij de volgende ronde

### Requirement: SSID-zichtbaarheid en signaalsterkte als metrics
De module SHALL per gevolgde SSID een `wifi_ssid_visible{ssid}` gauge (waarde `1` indien zichtbaar in de laatste scan, anders `0`) schrijven, en indien zichtbaar tevens een `wifi_signal_percent{ssid}` gauge met de sterkste gevonden signaalwaarde (0–100). Voor elke SSID in `watchSSIDs` SHALL áltijd een `wifi_ssid_visible`-regel worden geschreven, ook wanneer de SSID niet zichtbaar is, zodat de timeseries betrouwbaar bestaat.

#### Scenario: SSID zichtbaar
- **WHEN** een gevolgde SSID in het scanresultaat voorkomt
- **THEN** is `wifi_ssid_visible{ssid=...} == 1` en bevat `wifi_signal_percent{ssid=...}` de sterkste signaalwaarde van alle accesspoints met die SSID

#### Scenario: SSID niet zichtbaar
- **WHEN** een gevolgde SSID niet in het scanresultaat voorkomt
- **THEN** is `wifi_ssid_visible{ssid=...} == 0` en wordt er geen `wifi_signal_percent` voor die SSID geschreven

#### Scenario: SSID met bijzondere tekens
- **WHEN** een gevolgde SSID regex-metatekens (bijv. `.`, `[`, `+`) bevat
- **THEN** matcht de parsing de SSID als letterlijke string (fixed-string), niet als regex-patroon

### Requirement: Staleness-signaal voor kapotte scanner
De module SHALL bij elke geslaagde scan een `wifi_scan_last_success_timestamp_seconds` gauge schrijven met de unixtime van dat moment. Dit signaal SHALL alleen worden bijgewerkt wanneer het scan-script volledig succesvol doorloopt, zodat een falende scan (nmcli hangt, wifi-kaart weg) detecteerbaar is via een verouderde timestamp.

#### Scenario: Scan draait normaal
- **WHEN** het scan-script volledig doorloopt
- **THEN** bevat `wifi_scan.prom` een `wifi_scan_last_success_timestamp_seconds` met de huidige unixtime

#### Scenario: Scan faalt
- **WHEN** het scan-script vroegtijdig afbreekt (fout in `nmcli` of scan)
- **THEN** wordt `wifi_scan.prom` niet met een nieuwe timestamp overschreven en loopt de bestaande waarde achter

### Requirement: Generieke, label-gewijze alerting
De change SHALL Prometheus-alertregels toevoegen die generiek per SSID-timeseries evalueren, zonder SSID-specifieke labelfilters in de expressie. De regels SHALL worden ingelezen via een extra ruleFile in de Prometheus-config. De bestaande Alertmanager-configuratie SHALL ongewijzigd blijven; de alerts SHALL via de bestaande catch-all receiver worden afgeleverd.

#### Scenario: Gevolgde SSID valt weg
- **WHEN** `wifi_ssid_visible == 0` voor een gevolgde SSID gedurende 5 minuten
- **THEN** vuurt alert `WifiSSIDWeg` met het betreffende `ssid`-label in de annotatie, en wordt deze via de bestaande Alertmanager-receiver afgeleverd

#### Scenario: Nieuwe SSID vereist geen alert-wijziging
- **WHEN** een SSID aan `watchSSIDs` wordt toegevoegd
- **THEN** dekt de bestaande `WifiSSIDWeg`-regel die SSID automatisch, zonder aanpassing aan alert-regels

#### Scenario: Scanner geeft geen updates meer
- **WHEN** `time() - wifi_scan_last_success_timestamp_seconds > 300` gedurende 5 minuten
- **THEN** vuurt alert `WifiScanStale` zodat een kapotte scanner opgemerkt wordt in plaats van stilzwijgend verouderde data
