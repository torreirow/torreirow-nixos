# Prometheus Test Alerts - Telegram Notificaties

Deze setup test Telegram notificaties via Prometheus Alertmanager.

## Hoe het werkt

1. **Textfile Collector**: Node exporter leest metrics uit `/tmp/prometheus-textfiles/test_metric.prom`
2. **Alert Rules**: Drie test alerts in `alerts/test-alerts.yml`:
   - `TestValueHigh`: Triggert wanneer waarde > 100
   - `TestValueLow`: Triggert wanneer waarde < 10
   - `TestMetricMissing`: Triggert wanneer metric niet meer gerapporteerd wordt

3. **Helper Script**: `set-test-metric.sh` om de test waarde te manipuleren

## Setup

### 1. Configureer Telegram secrets (als nog niet gedaan)

```bash
# Bot token
agenix -e secrets/module-monitoring-telegram_bot_token.age
# Plak je bot token (bijv: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz)

# Chat ID
agenix -e secrets/module-monitoring-telegram_chat_id.age
# Plak je chat ID (bijv: 987654321)
```

### 2. Deploy configuratie

```bash
sudo nixos-rebuild switch --flake .#malandro
```

### 3. Verifieer services

```bash
# Check Prometheus
sudo systemctl status prometheus.service
curl http://localhost:9090/-/healthy

# Check Alertmanager
sudo systemctl status prometheus-alertmanager.service
curl http://localhost:9093/-/healthy

# Check Node Exporter
curl http://localhost:9100/metrics | grep test_metric
```

## Test Scenarios

### Scenario 1: Hoge waarde (TestValueHigh alert)

```bash
./modules/monitoring/prometheus/set-test-metric.sh 150
```

**Verwacht:**
- Alert `TestValueHigh` triggert na 10 seconden
- Telegram notificatie: "Test metric value is too high"
- Severity: warning

### Scenario 2: Lage waarde (TestValueLow alert)

```bash
./modules/monitoring/prometheus/set-test-metric.sh 5
```

**Verwacht:**
- Alert `TestValueLow` triggert na 10 seconden
- Telegram notificatie: "Test metric value is too low"
- Severity: critical

### Scenario 3: Normale waarde (geen alerts)

```bash
./modules/monitoring/prometheus/set-test-metric.sh 50
```

**Verwacht:**
- Geen alerts triggeren
- Als er eerder een alert actief was, krijg je een "resolved" notificatie

### Scenario 4: Missing metric (TestMetricMissing alert)

```bash
./modules/monitoring/prometheus/set-test-metric.sh remove
```

**Verwacht:**
- Alert `TestMetricMissing` triggert na 1 minuut
- Telegram notificatie: "Test metric is missing"

## Monitoring

### Prometheus UI
```
https://prometheus.toorren.net/alerts
```

Bekijk actieve alerts en hun status.

### Alertmanager UI
```
https://alertmanager.toorren.net/
```

Bekijk welke alerts verstuurd zijn en hun geschiedenis.

### Logs

```bash
# Prometheus logs
sudo journalctl -u prometheus.service -f

# Alertmanager logs (inclusief Telegram verzending)
sudo journalctl -u prometheus-alertmanager.service -f

# Node exporter logs
sudo journalctl -u prometheus-node-exporter.service -f
```

### Manual checks

```bash
# Check of metric wordt geëxporteerd
curl -s http://localhost:9100/metrics | grep test_metric_value

# Check Prometheus configuratie
curl -s http://localhost:9090/api/v1/status/config | jq .

# Check actieve alerts
curl -s http://localhost:9090/api/v1/alerts | jq .

# Check Alertmanager status
curl -s http://localhost:9093/api/v1/status | jq .

# Check Alertmanager ontvangers
curl -s http://localhost:9093/api/v1/receivers | jq .
```

## Troubleshooting

### Geen Telegram notificaties

1. **Check Alertmanager logs:**
   ```bash
   sudo journalctl -u prometheus-alertmanager.service -n 100
   ```

   Zoek naar errors met "telegram" of "notification".

2. **Check secrets:**
   ```bash
   # Secrets moeten bestaan en correct zijn
   ls -la /run/alertmanager/

   # Test bot token (vervang met je eigen token)
   TOKEN=$(sudo cat /run/alertmanager/telegramBotToken)
   CHAT_ID=$(sudo cat /run/alertmanager/telegramChatId)
   curl "https://api.telegram.org/bot${TOKEN}/sendMessage?chat_id=${CHAT_ID}&text=Test"
   ```

3. **Check alert is actief:**
   ```bash
   curl -s http://localhost:9093/api/v2/alerts | jq .
   ```

### Metric wordt niet gevonden

1. **Check textfile directory:**
   ```bash
   ls -la /tmp/prometheus-textfiles/
   cat /tmp/prometheus-textfiles/test_metric.prom
   ```

2. **Check node exporter:**
   ```bash
   curl http://localhost:9100/metrics | grep test_metric
   ```

3. **Check Prometheus scrape:**
   ```bash
   curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="node")'
   ```

## Opschonen

Wanneer je klaar bent met testen:

```bash
# Verwijder test metric
./modules/monitoring/prometheus/set-test-metric.sh remove

# Of verwijder hele directory
sudo rm -rf /tmp/prometheus-textfiles/

# Optioneel: comment out test alerts in prometheus.nix
# ruleFiles = [ # ./alerts/test-alerts.yml ];
```

## Alert Message Template

De Telegram berichten gebruiken het template uit `alertmanager-telegram.nix`:

```
<b>{{ .Annotations.summary }}</b>
{{ .Annotations.description }}

Status: {{ .Status }}
Severity: {{ .Labels.severity }}
```

Pas dit template aan in `modules/monitoring/prometheus/alertmanager-telegram.nix` als je de berichten wilt customizen.
