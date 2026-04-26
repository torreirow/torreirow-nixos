# InvoicePlane Setup Guide

## Overzicht

InvoicePlane is een zelf-gehoste open source applicatie voor het beheren van offertes, facturen, klanten en betalingen.

**URL:** https://invoices.toorren.net
**Authenticatie:** Authelia (auth.toorren.net)

## Vereisten

- NixOS 25.11+
- MariaDB (geconfigureerd via module)
- PHP 8.3 met extensions (automatisch)
- Nginx met SSL (via ACME)

## Installatie

### 1. InvoicePlane downloaden

Download de laatste versie van InvoicePlane en pak uit in `/data/external/invoiceplane`:

```bash
# Maak directory aan (wordt automatisch gedaan via systemd.tmpfiles)
sudo mkdir -p /data/external/invoiceplane
cd /data/external/invoiceplane

# Download laatste versie (1.7.1)
sudo wget https://github.com/InvoicePlane/InvoicePlane/releases/download/v1.7.1/InvoicePlane-v1.7.1.zip
sudo unzip InvoicePlane-v1.7.1.zip
sudo rm InvoicePlane-v1.7.1.zip

# Zet juiste permissions
sudo chown -R nginx:nginx /data/external/invoiceplane
sudo chmod -R 755 /data/external/invoiceplane
```

### 2. Database configuratie

De MariaDB database en gebruiker worden automatisch aangemaakt door NixOS.

**Database details:**
- Database naam: `invoiceplane`
- Gebruiker: `invoiceplane`
- Host: `localhost` of `127.0.0.1`

Stel een wachtwoord in voor de database gebruiker:

```bash
sudo mysql -u root

# In MySQL prompt:
SET PASSWORD FOR 'invoiceplane'@'localhost' = PASSWORD('jouw-veilig-wachtwoord');
FLUSH PRIVILEGES;
EXIT;
```

### 3. InvoicePlane configuratie

Kopieer en bewerk het configuratiebestand:

```bash
cd /data/external/invoiceplane
sudo cp ipconfig.php.example ipconfig.php
sudo chown nginx:nginx ipconfig.php
```

Bewerk `ipconfig.php` met de database gegevens:

```php
IP_URL=https://invoices.toorren.net

# Database settings
DB_HOSTNAME=localhost
DB_USERNAME=invoiceplane
DB_PASSWORD=jouw-veilig-wachtwoord
DB_DATABASE=invoiceplane
DB_PORT=3306

# Disable setup warning in production
DISABLE_SETUP=false  # Zet op true na installatie

# Remove index.php from URLs
REMOVE_INDEXPHP=true
```

### 4. NixOS rebuild

```bash
cd ~/data/git/torreirow-nixos
sudo nixos-rebuild switch --flake .#malandro
```

### 5. Setup wizard

Ga naar https://invoices.toorren.net/setup en volg de installatie wizard:

1. Accepteer de licentie voorwaarden
2. Database credentials worden automatisch ingelezen
3. Maak een admin account aan
4. Voltooi de setup

**Na installatie:**

Zet `DISABLE_SETUP=true` in `ipconfig.php` om de setup wizard te blokkeren:

```bash
sudo nano /data/external/invoiceplane/ipconfig.php
# DISABLE_SETUP=true
```

### 6. Eerste gebruik

Login op https://invoices.toorren.net met je admin account.

**Aanbevolen instellingen:**
- Ga naar Settings → System Settings
- Stel je bedrijfsinformatie in
- Configureer email (SMTP via Postfix)
- Pas factuur templates aan
- Voeg klanten en producten toe

## Onderhoud

### Backup

```bash
# Database backup
sudo mysqldump -u invoiceplane -p invoiceplane > invoiceplane-backup-$(date +%Y%m%d).sql

# Files backup
sudo tar czf invoiceplane-files-$(date +%Y%m%d).tar.gz /data/external/invoiceplane
```

### Update

```bash
# Download nieuwe versie
cd /data/external/invoiceplane
sudo wget https://github.com/InvoicePlane/InvoicePlane/releases/download/vX.X.X/InvoicePlane-vX.X.X.zip

# Backup huidige installatie
sudo cp -r /data/external/invoiceplane /data/external/invoiceplane-backup

# Pak nieuwe versie uit (overschrijft bestanden, maar ipconfig.php blijft bestaan)
sudo unzip -o InvoicePlane-vX.X.X.zip

# Herstel permissions
sudo chown -R nginx:nginx /data/external/invoiceplane

# Ga naar /upgrade in browser
# https://invoices.toorren.net/upgrade
```

### Logs

```bash
# PHP-FPM logs
sudo journalctl -u phpfpm-invoiceplane -f

# Nginx logs
sudo journalctl -u nginx -f

# InvoicePlane application logs
sudo tail -f /data/external/invoiceplane/logs/log-*.php
```

### Troubleshooting

**Database verbinding problemen:**
```bash
# Test database verbinding
sudo mysql -u invoiceplane -p invoiceplane
```

**Permissions problemen:**
```bash
sudo chown -R nginx:nginx /data/external/invoiceplane
sudo chmod -R 755 /data/external/invoiceplane
```

**PHP modules ontbreken:**
```bash
# Check geladen modules
php -m | grep -E 'mysqli|gd|curl|mbstring'
```

## Functies

- **Facturen & Offertes:** Maak professionele facturen en offertes
- **Klantbeheer:** CRM-achtig klantenbeheer met custom fields
- **Betalingen:** Integratie met PayPal en Stripe
- **Projecten:** Project en taak management
- **Templates:** Aanpasbare factuur templates
- **Meertalig:** Nederlands en andere talen ondersteund
- **eInvoice:** Ondersteuning voor elektronische facturen

## Links

- **Website:** https://www.invoiceplane.com/
- **Documentatie:** https://wiki.invoiceplane.com/
- **GitHub:** https://github.com/InvoicePlane/InvoicePlane
- **Community:** https://community.invoiceplane.com/

## Module configuratie

De NixOS module configureert:
- ✅ PHP-FPM pool met PHP 8.3
- ✅ MariaDB database en gebruiker
- ✅ Nginx reverse proxy met SSL
- ✅ Authelia authenticatie
- ✅ Upload limiet 20MB
- ✅ PHP extensions (mysqli, gd, curl, mbstring, etc.)
- ✅ Automatische directory aanmaak

**Bestand:** `modules/invoiceplane.nix`
