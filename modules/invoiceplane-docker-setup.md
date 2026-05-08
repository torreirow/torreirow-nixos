# InvoicePlane Docker Setup Guide

## Overzicht

InvoicePlane draait nu als Docker container met de `funktionslust/invoiceplane` image.

**URL:** https://invoices.toorren.net
**Authenticatie:** Authelia (auth.toorren.net)
**Container port:** 8084 (internal)

## Architectuur

```
Internet → Nginx (443) → Authelia → Docker Container (8084) → InvoicePlane
                                            ↓
                                      Host MariaDB (3306)
```

- **InvoicePlane:** Docker container (funktionslust/invoiceplane)
- **Database:** Host MariaDB (niet in container)
- **Reverse proxy:** Nginx op host
- **Authenticatie:** Authelia op host
- **Data volume:** `/data/external/invoiceplane-docker/data`

## Initiële Setup

### 1. Database wachtwoord instellen

```bash
# Login als root in MariaDB
sudo mysql -u root

# Stel wachtwoord in voor invoiceplane gebruiker
SET PASSWORD FOR 'invoiceplane'@'localhost' = PASSWORD('jouw-veilig-wachtwoord');
FLUSH PRIVILEGES;
EXIT;
```

### 2. Database wachtwoord bestand aanmaken

Het Docker container leest het database wachtwoord uit een file (veiliger dan environment variable).

```bash
# Maak wachtwoord bestand aan
sudo mkdir -p /data/external/invoiceplane-docker
echo -n 'jouw-veilig-wachtwoord' | sudo tee /data/external/invoiceplane-docker/db_password.txt
sudo chmod 600 /data/external/invoiceplane-docker/db_password.txt
```

**LET OP:** Gebruik `echo -n` (zonder newline) om geen extra whitespace toe te voegen!

### 3. NixOS rebuild

```bash
cd ~/data/git/torreirow-nixos
sudo nixos-rebuild switch --flake .#malandro
```

Dit zal:
- Docker compose configuratie aanmaken in `/etc/invoiceplane/docker-compose.yml`
- InvoicePlane container downloaden en starten
- Nginx virtual host configureren
- Authelia authenticatie activeren

### 4. Container status controleren

```bash
# Check of container draait
sudo docker ps | grep invoiceplane

# Container logs bekijken
sudo docker logs invoiceplane -f

# Systemd service status
sudo systemctl status invoiceplane-docker
```

### 5. Setup wizard uitvoeren

Ga naar https://invoices.toorren.net en volg de installatie wizard:

1. Login via Authelia (wouter@toorren.net)
2. Accepteer de licentie voorwaarden
3. Database credentials worden automatisch ingelezen via environment variables
4. Maak een admin account aan voor InvoicePlane zelf
5. Voltooi de setup

**Na installatie:**

De eerste keer moet je `DISABLE_SETUP` nog op `false` laten staan. Na de eerste setup kun je dit op `true` zetten in de module en opnieuw rebuilden.

### 6. Setup wizard blokkeren (na installatie)

Bewerk `/home/wtoorren/data/git/torreirow-nixos/modules/invoiceplane-docker.nix`:

```nix
- DISABLE_SETUP=false
+ DISABLE_SETUP=true
```

Rebuild:

```bash
sudo nixos-rebuild switch --flake .#malandro
```

## Docker Management

### Container beheer

```bash
# Container herstarten
sudo systemctl restart invoiceplane-docker

# Container stoppen
sudo systemctl stop invoiceplane-docker

# Container starten
sudo systemctl start invoiceplane-docker

# Logs volgen
sudo docker logs invoiceplane -f

# Container shell (troubleshooting)
sudo docker exec -it invoiceplane /bin/bash
```

### Docker Compose commando's

```bash
cd /etc/invoiceplane

# Status
sudo docker compose ps

# Logs
sudo docker compose logs -f

# Herstarten
sudo docker compose restart

# Stoppen en verwijderen
sudo docker compose down

# Opnieuw opstarten
sudo docker compose up -d
```

### Image updaten

```bash
# Pull nieuwe image
sudo docker compose -f /etc/invoiceplane/docker-compose.yml pull

# Herstart service (pakt automatisch nieuwe image)
sudo systemctl restart invoiceplane-docker

# Of handmatig via docker-compose
cd /etc/invoiceplane
sudo docker compose down
sudo docker compose up -d
```

## Database Management

### Database toegang (host MariaDB)

```bash
# Login als invoiceplane gebruiker
sudo mysql -u invoiceplane -p invoiceplane

# Login als root
sudo mysql -u root invoiceplane
```

### Backup

```bash
# Database backup
sudo mysqldump -u invoiceplane -p invoiceplane > invoiceplane-backup-$(date +%Y%m%d).sql

# Files backup (uploads)
sudo tar czf invoiceplane-files-$(date +%Y%m%d).tar.gz /data/external/invoiceplane-docker/data
```

### Restore

```bash
# Database restore
sudo mysql -u invoiceplane -p invoiceplane < invoiceplane-backup-20260425.sql
```

## Nginx Configuratie

Nginx draait op de host en proxyt naar de Docker container:

- **External:** https://invoices.toorren.net:443
- **Internal:** http://127.0.0.1:8084

Authelia authenticatie gebeurt VOOR de proxy naar Docker, dus de container ziet alleen authenticated requests.

## Troubleshooting

### Container start niet

```bash
# Check systemd service
sudo systemctl status invoiceplane-docker

# Check docker logs
sudo docker logs invoiceplane

# Check of port 8084 vrij is
sudo netstat -tlnp | grep 8084
```

### Database verbinding mislukt

Het Docker container verbindt naar de host MariaDB via `172.17.0.1` (Docker bridge IP).

```bash
# Test database toegang vanaf host
sudo mysql -u invoiceplane -p -h 127.0.0.1 invoiceplane

# Check of MySQL luistert op Docker interface
sudo netstat -tlnp | grep 3306

# Check firewall regel
sudo iptables -L -n | grep 3306
```

### 502 Bad Gateway

```bash
# Check of container draait
sudo docker ps | grep invoiceplane

# Check container health
sudo docker inspect invoiceplane | grep -A 5 Health

# Check logs
sudo docker logs invoiceplane -f
```

### Uploads werken niet

```bash
# Check volume mount
sudo docker inspect invoiceplane | grep -A 10 Mounts

# Check permissions in container
sudo docker exec invoiceplane ls -la /var/www/html/uploads

# Check permissions op host
sudo ls -la /data/external/invoiceplane-docker/data
```

## Migratie van Native naar Docker

Als je van de oude native PHP-FPM setup komt:

### 1. Backup oude data

```bash
# Backup oude uploads
sudo cp -r /data/external/invoiceplane/uploads /data/external/invoiceplane-backup/

# Database is hetzelfde, geen backup nodig
```

### 2. Stop oude services

De oude PHP-FPM pool en Nginx config worden automatisch vervangen door de nieuwe module.

### 3. Kopieer uploads naar nieuwe locatie

```bash
sudo cp -r /data/external/invoiceplane/uploads/* /data/external/invoiceplane-docker/data/
sudo chown -R 1000:1000 /data/external/invoiceplane-docker/data
```

### 4. Database blijft hetzelfde

De database `invoiceplane` op host MariaDB blijft bestaan, dus geen migratie nodig.

## Configuratie Aanpassen

### Environment variables

Bewerk `/home/wtoorren/data/git/torreirow-nixos/modules/invoiceplane-docker.nix`:

```nix
environment:
  - IP_URL=https://invoices.toorren.net
  - PHP_MEMORY_LIMIT=512M  # Verhogen indien nodig
  - PHP_UPLOAD_MAX_FILESIZE=50M  # Grotere uploads
```

Na wijzigingen:

```bash
sudo nixos-rebuild switch --flake .#malandro
```

Dit triggert automatisch een herstart van de container.

### Port wijzigen

Standaard draait InvoicePlane op internal port 8084. Om te wijzigen:

Bewerk `modules/invoiceplane-docker.nix`:

```nix
let
  invoiceplanePort = "8085";  # Nieuwe port
```

Rebuild en herstart.

## Voordelen Docker Setup

- ✅ Automatische installatie (geen ZIP downloaden)
- ✅ Eenvoudige updates (docker pull)
- ✅ Geïsoleerde omgeving
- ✅ Zelfde database als native setup
- ✅ Authelia authenticatie behouden
- ✅ Declaratieve configuratie via NixOS
- ✅ Automatische container restart bij crash

## Links

- **Image:** https://hub.docker.com/r/funktionslust/invoiceplane
- **InvoicePlane:** https://www.invoiceplane.com/
- **Documentatie:** https://wiki.invoiceplane.com/
- **GitHub:** https://github.com/InvoicePlane/InvoicePlane

## Checklist Setup

- [ ] Database wachtwoord ingesteld voor `invoiceplane@localhost`
- [ ] Database wachtwoord bestand aangemaakt (`/data/external/invoiceplane-docker/db_password.txt`)
- [ ] NixOS rebuild uitgevoerd
- [ ] Container status gecontroleerd (`docker ps`)
- [ ] Setup wizard voltooid (https://invoices.toorren.net)
- [ ] `DISABLE_SETUP=true` gezet na installatie
- [ ] Uploads getest
- [ ] Backup strategie ingesteld
