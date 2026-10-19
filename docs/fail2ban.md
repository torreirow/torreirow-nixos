# Fail2ban (malandro)

modules/fail2ban.nix, de jails en de NixOS 25.11-opties die NIET op top-level bestaan.

> Verplaatst uit CLAUDE.md (Huidige Status) om de sessie-context slank te houden.

#### 2. Fail2ban configuratie (malandro)
- **Nieuw bestand:** `modules/fail2ban.nix`
- **Status:** Module aangemaakt en toegevoegd aan malandro configuratie

**Configuratie details:**
- SSH jail: 5 pogingen binnen 10 min → 10 min ban
- Nginx jails: Automatisch actief als nginx enabled is
- Whitelist: 192.168.2.0/24 (lokaal netwerk)
- Backend: systemd (automatisch, geen expliciete configuratie nodig)

**NixOS 25.11 specifiek:**
- ❌ `services.fail2ban.backend` bestaat niet meer
- ❌ `services.fail2ban.maxretry` bestaat niet op top-level
- ❌ `services.fail2ban.bantime` bestaat niet op top-level
- ❌ `services.fail2ban.findtime` bestaat niet op top-level
- ✅ Deze opties werken WEL binnen jail configuraties
- ✅ `ignoreIP`, `banaction`, `banaction-allports` werken op top-level

#### 3. Jail `nginx-scanner` (2026-10-19)
Aanleiding: scanner 45.61.187.50 probeerde op 8 sep, 16 sep en 18 okt Joomla-exploits (JCE, SP Page
Builder). De bestaande nginx-jails zagen niets: die matchen auth-/limit-fouten uit de journal
(`error_log stderr`), geen 404-scans in het access-log.

- **Bron:** `/var/log/nginx/access.log` als bestand → `backend = auto` in de jail (de rest staat
  op `systemd`, het access-log komt niet in de journal).
- **Filter:** 4xx op `.php`, `wp-`, `xmlrpc`, `/administrator/`, `com_`, `/.env`, `/.git/`, ... plus
  elke `POST /index.php?option=com_jce|sppagebuilder|...`. 5 hits in 10 min → ban van 1 dag.
- **Valkuil (getoetst op 5 maanden log):** de eigen Nextcloud-client krijgt legitiem 404's op
  `/ocs/v2.php/apps/terms_of_service/...`. Daarom tellen alleen requests zonder ingelogde gebruiker
  (`- - [`) en zijn `/ocs`, `/remote.php`, `/index.php/`, `/status.php`, `/public.php`, `/apps/`
  uitgezonderd.
- **Logformaat:** nginx logt sinds dezelfde wijziging `combined` + `host=$host` **aan het eind** van
  de regel (`modules/nginx.nix`). Zet de host nooit vooraan: dan breken de `^<HOST>`-regexen.
- **Testen:** `fail2ban-regex /var/log/nginx/access.log /etc/fail2ban/filter.d/nginx-scanner.conf`

## Commandos

### Fail2ban (malandro)
```bash
# Status van alle jails
sudo fail2ban-client status

# Details van specifieke jail
sudo fail2ban-client status sshd
sudo fail2ban-client status nginx-http-auth

# Gebande IPs
sudo fail2ban-client banned

# Logs volgen
sudo journalctl -u fail2ban -f

# IP handmatig bannen/unbannen
sudo fail2ban-client set sshd banip 1.2.3.4
sudo fail2ban-client set sshd unbanip 1.2.3.4
```
