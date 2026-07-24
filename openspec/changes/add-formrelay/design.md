## Context

Malandro draait al nginx (reverse proxy met TLS) en postfix (SMTP relay via AWS SES). De statische websites hebben geen backend en kunnen daardoor geen formulieren verwerken. De oplossing is een minimale Go service die uitsluitend als form-to-email gateway dient, naadloos aansluit op de bestaande infrastructuur en als NixOS module declaratief configureerbaar is.

## Goals / Non-Goals

**Goals:**
- AJAX contactformulierverwerking voor 4 statische sites
- hCaptcha verificatie + Origin check + honeypot spam bescherming
- Declaratieve NixOS module met agenix secret integratie
- Herbruikbaar voor toekomstige statische sites via token systeem

**Non-Goals:**
- Geen formulier builder UI (forms worden in HTML geschreven)
- Geen opslag van inzendingen (enkel email)
- Geen bestandsbijlagen
- Geen auto-reply naar de afzender
- Geen dashboard of analytics

## Decisions

### 1. Implementatietaal: Go

**Keuze**: Go binary via `buildGoModule`

**Rationale**: Single binary zonder runtime dependencies. Eenvoudig te verpakken als NixOS derivation. Standaardbibliotheek dekt HTTP server, SMTP en JSON af. Past bij het bestaande patroon van native services op malandro (Vaultwarden, Authelia, Vikunja).

**Alternatief overwogen**: Python (Flask) — eenvoudiger te schrijven maar vereist Python runtime en package management in Nix.

### 2. Configuratie via JSON bestand

**Keuze**: Nix genereert een JSON config file (`/etc/formrelay/config.json`) via `pkgs.writeText` of `environment.etc`. De service leest dit bij opstarten.

**Rationale**: Token map en instellingen zijn geen geheimen (behalve hCaptcha secret key). JSON config kan door Nix worden gegenereerd vanuit module opties zonder complexe templating.

**hCaptcha secret key**: Via agenix, pad doorgegeven als `--hcaptcha-secret-file` argument aan de binary.

### 3. Port 8094 op 127.0.0.1

**Keuze**: Service luistert op `127.0.0.1:8094`, nginx proxiet `forms.toorren.net` ernaar.

**Rationale**: Consistent met andere services op malandro (zie PORTS.md). Externe toegang uitsluitend via nginx met TLS.

### 4. AJAX JSON response (geen redirect)

**Keuze**: Endpoint retourneert altijd JSON: `{"ok": true}` of `{"ok": false, "error": "..."}`.

**Rationale**: Gebruiker wil inline feedback zonder paginarefresh. Formulieren op de statische sites gebruiken JavaScript voor de POST en tonen het resultaat in de pagina.

**CORS**: Response bevat `Access-Control-Allow-Origin` header op basis van de `allowedOrigins` uit de token configuratie. Alleen geregistreerde origins krijgen een succesrespons.

### 5. Email via localhost SMTP

**Keuze**: `net/smtp` pakket stuurt naar `127.0.0.1:25` (postfix).

**Rationale**: Postfix is al geconfigureerd als AWS SES relay. Geen extra authenticatie nodig voor lokale verbindingen.

**Email formaat**: Plain text. Onderwerp: `[Formulier: <token naam>] Nieuw bericht van <naam>`. Body bevat alle veldwaarden behalve `_token`, `_honeypot` en `h-captcha-response`.

### 6. Spam bescherming in lagen

**Keuze**: Drie lagen gecombineerd:
1. hCaptcha server-side verificatie (primair)
2. Origin header check tegen `allowedOrigins` per token
3. Honeypot veld `_gotcha` (conventioneel veld — bots vullen het in, server verwerpt het verzoek stilzwijgend)

**nginx rate limiting**: Al aanwezig in `modules/nginx.nix` (`limit_req_zone`), geldt ook voor `forms.toorren.net`.

### 7. Go broncode locatie

**Keuze**: `pkgs/formrelay/` directory in de repo met `main.go` en `go.mod`. NixOS module verwijst naar `pkgs.callPackage ../../../pkgs/formrelay {}`.

**Rationale**: Scheidt broncode van NixOS configuratie. Makkelijk te testen buiten Nix context.

## Risks / Trade-offs

- **hCaptcha API beschikbaarheid** → Als api.hcaptcha.com tijdelijk onbereikbaar is, falen alle formulieren. Mitigatie: timeout van 5 seconden, duidelijke foutmelding terug naar gebruiker.
- **Token zichtbaar in HTML** → Bewust geaccepteerd (zie explore sessie). Token is routing ID, geen beveiligingslaag. Origin check + hCaptcha vormen de werkelijke beveiliging.
- **Geen persistentie** → Bij serverfout gaat een inzending verloren. Acceptabel voor contactformulieren op persoonlijke sites.
- **Single SMTP dependency** → Als postfix down is, falen formulieren. Mitigatie: postfix is simpele relay, heeft hoge uptime.

## Migration Plan

1. Voeg `secrets/hcaptcha-secret.age` toe (encrypt met agenix)
2. Schrijf `pkgs/formrelay/main.go` en `go.mod`
3. Schrijf `modules/formrelay.nix`
4. Voeg module toe aan `hosts/malandro/configuration.nix`
5. Update `PORTS.md` met port 8094
6. `sudo nixos-rebuild switch --flake .#malandro`
7. DNS record `forms.toorren.net` → malandro IP
8. Voeg formulier HTML + JavaScript toe aan de sites

**Rollback**: Module import verwijderen uit configuration.nix, rebuild. Stateless service, geen datamigratie nodig.

## Open Questions

- Welk emailadres als `From:` adres? Voorstel: `forms@toorren.net` (aliased via AWS SES)
- hCaptcha site keys: één gedeelde key voor alle sites of per site? (hCaptcha ondersteunt meerdere domeinen per site key — één key is praktisch)
