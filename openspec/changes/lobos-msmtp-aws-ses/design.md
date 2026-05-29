## Context

Malandro gebruikt een volledige Postfix daemon als AWS SES relay. Voor lobos (desktop/laptop) is een daemon-based aanpak overkill: er is geen inkomende mail, geen lokale delivery, en de machine is niet altijd aan. `msmtp` is een lichtgewicht SMTP client die werkt als `sendmail`-vervanging — ideaal voor desktop use cases.

Het `postfix-sasl-password.age` secret op malandro heeft een Postfix-specifiek formaat (`[host]:port USER:PASS`). Voor msmtp is een apart secret met alleen het wachtwoord schoner en onafhankelijker.

Het domein `toorren.net` is al geverifieerd in AWS SES eu-central-1. De SMTP credentials (IAM user) zijn dezelfde als op malandro.

## Goals / Non-Goals

**Goals:**
- `msmtp` beschikbaar als `sendmail`-vervanging op lobos
- Mails versturen via AWS SES vanuit scripts en command line
- Afzender `lobos@toorren.net`
- Credentials veilig opslaan via agenix

**Non-Goals:**
- Inkomende mail ontvangen
- Lokale mail delivery (geen `/var/spool/mail`)
- GUI mail client integratie
- Gedeelde credentials met malandro (aparte secret, zelfde IAM user)

## Decisions

### msmtp i.p.v. Postfix

**Keuze:** `programs.msmtp` (NixOS module)
**Alternatieven:** Postfix relay (zoals malandro), ssmtp (deprecated), nullmailer

Postfix is zwaarder dan nodig voor een desktop die alleen mail wil sturen. msmtp heeft geen daemon, start niet bij boot, en is perfect voor "send-only" use cases. NixOS heeft een native `programs.msmtp` module die ook de `sendmail` symlink regelt.

### Apart secret voor msmtp

**Keuze:** Nieuw `secrets/msmtp-password.age` met alleen het SMTP wachtwoord
**Alternatief:** `postfix-sasl-password.age` hergebruiken via `passwordeval` + shell parsing

Het postfix secret heeft een Postfix-specifiek formaat. Parsen hiervan in msmtp config is fragiel. Een apart secret met alleen het wachtwoord is schoner, explicieter, en onafhankelijk van de postfix module.

### Configuratie locatie

**Keuze:** Nieuw bestand `hosts/lobos/mail.nix`, geïmporteerd in `configuration.nix`
**Alternatief:** Direct in `configuration.nix` of in `programs.nix`

Consistent met de patronen in dit project (power-management.nix, gnome-wayland.nix): functionaliteit in eigen module bestand.

## Risks / Trade-offs

- **[Risk] AWS SES rate limits** → Geen probleem voor sporadisch gebruik vanaf desktop
- **[Risk] Secret lekt bij misconfiguratie** → agenix zorgt voor encrypted opslag; secret alleen leesbaar voor root
- **[Risk] `tls_fingerprint` drift bij AWS cert rotatie** → Gebruik `tls_trust_file` i.p.v. fingerprint voor langdurige stabiliteit

## Migration Plan

1. Nieuw secret aanmaken: `agenix -e secrets/msmtp-password.age`
2. Secret toevoegen aan `secrets/secrets.nix` voor `lobos` public key
3. `hosts/lobos/mail.nix` aanmaken met `programs.msmtp` configuratie
4. Module importeren in `hosts/lobos/configuration.nix`
5. `sudo nixos-rebuild switch --flake .#lobos`
6. Testen: `echo "Test" | mail -s "Test lobos" wtoorren@toorren.net`

Rollback: module import verwijderen en rebuild.
