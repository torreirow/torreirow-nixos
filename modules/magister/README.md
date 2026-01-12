# Magister Service Setup voor NixOS

Deze setup maakt een systemd service die automatisch draait en stopt als de sessie ongeldig is.

## Installatie

### Stap 1: Kopieer bestanden naar de server

```bash
# Maak directory aan
sudo mkdir -p /var/lib/magister
sudo chown -R magister:magister /var/lib/magister  # wordt automatisch aangemaakt

# Kopieer bestanden
sudo cp magister_server.py /var/lib/magister/
sudo cp magister-service.nix /etc/nixos/
```

### Stap 2: Import de module in configuration.nix

Voeg toe aan `/etc/nixos/configuration.nix`:

```nix
{ config, pkgs, ... }:

{
  imports = [
    # ... je andere imports ...
    ./magister-service.nix
  ];

  # Enable de Magister service
  services.magister-sync = {
    enable = true;
    workingDirectory = "/var/lib/magister";  # Optioneel, dit is de default
    user = "magister";                        # Optioneel, dit is de default
    group = "magister";                       # Optioneel, dit is de default

    # Nginx configuratie voor iCal feeds (publiek toegankelijk)
    # Google Calendar ondersteunt geen authenticatie, dus feeds zijn publiek
    nginx = {
      enable = true;
      domain = "agenda.toorren.net";
      acmeHost = "toorren.net";

      # Configureer kinderen (standaard: noraly en boaz)
      children = [
        { name = "noraly"; path = "/noraly"; }
        { name = "boaz"; path = "/boaz"; }
      ];
    };
  };

  # Rest van je configuratie...
}
```

### Stap 3: Rebuild en start de service

```bash
# Rebuild NixOS configuratie
sudo nixos-rebuild switch

# Check status (zal waarschijnlijk failed zijn omdat sessie er nog niet is)
sudo systemctl status magister-sync
```

### Stap 4: Kopieer sessie bestand

Op je **laptop**:
```bash
# Genereer verse sessie
nix-shell shell.nix
python magister_login.py

# Kopieer naar server
scp magister_session.json user@server:/tmp/
```

Op de **server**:
```bash
# Verplaats naar service directory
sudo mv /tmp/magister_session.json /var/lib/magister/
sudo chown magister:magister /var/lib/magister/magister_session.json
sudo chmod 600 /var/lib/magister/magister_session.json

# Herstart service
sudo systemctl restart magister-sync
sudo systemctl status magister-sync
```

## Service beheer

### Logs bekijken
```bash
# Realtime logs
sudo journalctl -u magister-sync -f

# Laatste 50 regels
sudo journalctl -u magister-sync -n 50

# Logs van vandaag
sudo journalctl -u magister-sync --since today
```

### Service status
```bash
sudo systemctl status magister-sync
```

### Service stoppen/starten
```bash
sudo systemctl stop magister-sync
sudo systemctl start magister-sync
sudo systemctl restart magister-sync
```

### Service uitschakelen
```bash
sudo systemctl disable magister-sync
sudo systemctl stop magister-sync
```

## Gedrag bij ongeldige sessie

De service zal **automatisch stoppen** als:
- Het sessie bestand niet bestaat
- De sessie verlopen/ongeldig is

De service zal **NIET automatisch herstarten** bij exit code 1 (sessie probleem).

Je moet dan handmatig:
1. Een nieuwe sessie genereren op je laptop
2. Het sessie bestand kopiëren naar de server
3. De service herstarten met `sudo systemctl restart magister-sync`

## Output bestanden

De service maakt de volgende iCal bestanden aan in `/var/lib/magister/`:
- `magister_noraly.ics`
- `magister_boaz.ics`

Deze worden elke 28 minuten bijgewerkt.

## Troubleshooting

### Service start niet
```bash
# Check logs voor details
sudo journalctl -u magister-sync -n 100

# Check of bestanden bestaan
ls -la /var/lib/magister/
```

### Permissie problemen
```bash
# Fix ownership
sudo chown -R magister:magister /var/lib/magister/
sudo chmod 700 /var/lib/magister/
sudo chmod 600 /var/lib/magister/magister_session.json
```

### Sessie blijft ongeldig
Mogelijk is er IP-binding. Genereer de sessie direct op de server:
```bash
# Met X forwarding
ssh -X user@server
cd /var/lib/magister
sudo -u magister nix-shell /tmp/magister.new/shell.nix
python magister_login.py
```

## Configuratie opties

Je kunt de volgende opties aanpassen in `configuration.nix`:

```nix
services.magister-sync = {
  enable = true;

  # Verander de working directory
  workingDirectory = "/home/jouw-user/magister";

  # Draai als een andere user
  user = "jouw-user";
  group = "jouw-group";
};
```

## Gebruik met Google Calendar

### Stap 1: Open Google Calendar

Ga naar [Google Calendar](https://calendar.google.com/)

### Stap 2: Agenda toevoegen

1. Klik links op het **+** naast "Andere agenda's"
2. Kies **"Via URL"**
3. Plak één van deze URLs:
   - `https://agenda.toorren.net/noraly` (voor Noraly)
   - `https://agenda.toorren.net/boaz` (voor Boaz)
4. Klik **"Agenda toevoegen"**

**Let op:** De feeds zijn publiek toegankelijk. Google Calendar ondersteunt geen authenticatie voor externe kalenders.

### Stap 3: Herhaal voor elk kind

Voeg beide agenda's toe als aparte kalenders.

### Update frequentie

Google Calendar update externe kalenders ongeveer elke 24 uur. De iCal bestanden op je server worden wel elke 28 minuten bijgewerkt.

## Overzichtspagina

Bezoek `https://agenda.toorren.net/` voor een overzicht van alle beschikbare feeds met de juiste URLs.

## Nginx configuratie opties

De module biedt verschillende configuratie opties:

```nix
services.magister-sync.nginx = {
  # Enable nginx
  enable = true;

  # Domein configuratie
  domain = "agenda.toorren.net";
  acmeHost = "toorren.net";  # Voor Let's Encrypt certificaat

  # Kinderen configuratie
  children = [
    { name = "noraly"; path = "/noraly"; }
    { name = "boaz"; path = "/boaz"; }
    # Voeg meer toe indien nodig:
    # { name = "kind3"; path = "/kind3"; }
  ];
};
```

### Nginx features:

✅ **Automatische HTTPS** via Let's Encrypt (useACMEHost)
✅ **CORS headers** voor Google Calendar compatibiliteit
✅ **Correcte MIME types** (text/calendar)
✅ **Cache headers** (5 minuten)
✅ **Security headers** (X-Frame-Options, etc.)
✅ **Publieke toegang** (vereist voor Google Calendar)
✅ **Overzichtspagina** op root URL

### Beveiliging

De iCal feeds zijn publiek toegankelijk zonder authenticatie. Dit is noodzakelijk omdat Google Calendar geen authenticatie ondersteunt voor externe kalenders.

Als je meer beveiliging wilt, kun je:
- De URLs niet delen/publiceren (security by obscurity)
- Firewall rules instellen om alleen bepaalde IP-ranges toe te laten
- Een andere oplossing gebruiken (bijv. Nextcloud CalDAV)
