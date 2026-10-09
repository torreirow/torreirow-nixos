# InvoicePlane Docker (invoices.toorren.net)

OCI-container op poort 8092, host-MariaDB, de .htaccess-workaround en proxy-header-les.

> Verplaatst uit CLAUDE.md (Huidige Status) om de sessie-context slank te houden.

### Sessie 2026-04-26 - InvoicePlane Docker setup - OPGELOST

**Doel:** InvoicePlane (open source facturatie platform) toevoegen aan malandro via Docker.

**Configuratie:**
- **URL:** `https://invoices.toorren.net`
- **Port:** 8092 (localhost binding)
- **Container:** `funktionslust/invoiceplane:latest`
- **Database:** Bestaande MariaDB op host (localhost)
  - Database: `invoiceplane`
  - Gebruiker: via `secrets/invoiceplane-env.age`
  - Wachtwoord: via `secrets/invoiceplane-env.age`
- **Authenticatie:** Authelia (verplicht)

**Problemen opgelost:**

1. **Port conflict (8084)**
   - Probleem: Port 8084 was al in gebruik door Pi-hole FTL
   - Oplossing: InvoicePlane verplaatst naar port 8092
   - `PORTS.md` bijgewerkt met DocSeal (8090) en InvoicePlane (8092)

2. **Bad Request (400) via nginx**
   - Probleem: Apache gaf "Bad Request" bij requests via nginx
   - Diagnose: Dubbele proxy headers (handmatig + NixOS `recommendedProxySettings`)
   - Oplossing: Handmatige proxy headers verwijderd, NixOS voegt ze automatisch toe

3. **404 Not Found voor /welcome route**
   - Probleem: InvoicePlane routes gaven 404 (bijv. `/welcome`)
   - Diagnose: `.htaccess` bestand ontbrak (bestaat als `htaccess` zonder punt)
   - Root cause: `REMOVE_INDEXPHP=true` env var werkt niet in dit Docker image
   - Oplossing: `ExecStartPost` script dat `htaccess` naar `.htaccess` kopieert bij container start

3. **Module structuur**
   - Van docker-compose naar OCI containers (zoals DocSeal)
   - Alle configuratie via age-encrypted environment file
   - Nginx virtualHost direct in module

**Bestanden gewijzigd:**
- `modules/invoiceplane-docker.nix` - Nieuwe module (OCI containers)
- `hosts/malandro/configuration.nix` - Module import toegevoegd
- `secrets/invoiceplane-env.age` - Database credentials (encrypted)
- `PORTS.md` - DocSeal (8090) en InvoicePlane (8092) toegevoegd

**Belangrijke lessen:**
- ✅ Gebruik OCI containers in plaats van docker-compose voor nieuwe services
- ✅ Check `PORTS.md` voor vrije poorten voordat je een service toevoegt
- ✅ NixOS voegt automatisch proxy headers toe via `recommendedProxySettings` - stel deze niet handmatig in
- ✅ Docker containers kunnen host MariaDB bereiken via `host.docker.internal` (met `--add-host=host.docker.internal:host-gateway`)
- ✅ Nginx reverse proxy betekent NIET dat .htaccess niet nodig is - Apache in de container heeft nog steeds .htaccess nodig voor routing
- ✅ Docker image bugs kunnen workarounds vereisen (zoals ExecStartPost voor .htaccess setup)

**Status:** ✅ InvoicePlane live op https://invoices.toorren.net
