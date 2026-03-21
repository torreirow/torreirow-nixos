# Postfix AWS SES SMTP Relay Setup

Deze module configureert Postfix als SMTP relay via Amazon SES (Simple Email Service).

## Vereisten

1. AWS account met toegang tot SES
2. Geverifieerde email adressen of domein in SES
3. SMTP credentials aangemaakt in AWS SES
4. Agenix geconfigureerd in je NixOS flake

## Stap 1: AWS SES SMTP Credentials verkrijgen

### Via AWS Console

1. Log in op AWS Console
2. Ga naar **Amazon SES** service
3. Kies je regio (bijv. `eu-west-1` voor Ierland)
4. Navigeer naar **SMTP Settings** (onder "Configuration" in het linker menu)
5. Klik op **Create SMTP Credentials**
6. Geef een IAM gebruikersnaam op (bijv. `ses-smtp-user-malandro`)
7. Klik **Create User**
8. **Download** de credentials (of kopieer ze - je kunt ze later niet meer zien!)

Je krijgt:
- **SMTP Username**: Begint meestal met `AKIA...`
- **SMTP Password**: Een lange string

### SES Sandbox Mode

**Let op**: Nieuwe AWS accounts starten in SES Sandbox mode. In deze mode kun je alleen mailen naar:
- Geverifieerde email adressen
- Geverifieerde domeinen
- Amazon SES mailbox simulator adressen

Om uit de sandbox te komen, moet je een "Request Production Access" indienen via de AWS Console.

## Stap 2: Email adres of domein verifiëren

### Email adres verifiëren (voor testing)

1. Ga naar **Verified identities** in SES
2. Klik **Create identity**
3. Kies **Email address**
4. Voer je email in (bijv. `noreply@toorren.net`)
5. Klik **Create identity**
6. Check je mailbox en klik op de verificatielink

### Domein verifiëren (productie)

1. Ga naar **Verified identities** in SES
2. Klik **Create identity**
3. Kies **Domain**
4. Voer je domein in (bijv. `toorren.net`)
5. Selecteer **Easy DKIM** en **DKIM signing key length: 2048-bit**
6. Voeg de DNS records toe die AWS toont (DKIM, MX, SPF)
7. Wacht op verificatie (kan tot 72 uur duren, meestal binnen minuten)

## Stap 3: Secrets bestand aanmaken

### Formaat

Het secrets bestand moet deze structuur hebben:

```
[email-smtp.REGION.amazonaws.com]:587 SMTP_USERNAME:SMTP_PASSWORD
```

**Voorbeeld** (fictieve credentials):

```
[email-smtp.eu-west-1.amazonaws.com]:587 AKIAIOSFODNN7EXAMPLE:wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

### Aanmaken en encrypten

```bash
# Maak een plaintext bestand met je credentials
cat > /tmp/postfix-sasl-password.txt << 'EOF'
[email-smtp.eu-west-1.amazonaws.com]:587 AKIAXXXXXXXXXXXXXXXX:BDjXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
EOF

# Encrypt met agenix (vanuit je NixOS repo root)
cd ~/data/git/torreirow-nixos
agenix -e secrets/postfix-sasl-password.age

# Plak de inhoud van /tmp/postfix-sasl-password.txt
# Bewaar en sluit de editor

# Verwijder het plaintext bestand
rm /tmp/postfix-sasl-password.txt
```

**Belangrijke opmerkingen:**
- Vervang `eu-west-1` met je AWS regio
- Vervang de AKIA credentials met je eigen SMTP credentials
- **Let op de dubbele punt** tussen username en password
- **Let op het poortnummer** `:587` achter de hostname

### Beschikbare AWS SES regio's

| Regio | Endpoint |
|-------|----------|
| US East (N. Virginia) | `email-smtp.us-east-1.amazonaws.com` |
| US West (Oregon) | `email-smtp.us-west-2.amazonaws.com` |
| EU (Ireland) | `email-smtp.eu-west-1.amazonaws.com` |
| EU (Frankfurt) | `email-smtp.eu-central-1.amazonaws.com` |
| Asia Pacific (Mumbai) | `email-smtp.ap-south-1.amazonaws.com` |
| Asia Pacific (Sydney) | `email-smtp.ap-southeast-2.amazonaws.com` |

Zie [AWS SES documentatie](https://docs.aws.amazon.com/ses/latest/dg/smtp-connect.html) voor een volledige lijst.

## Stap 4: Module configureren

### Module aanpassen

Open `modules/postfix.nix` en pas de volgende variabelen aan:

```nix
let
  awsRegion = "eu-west-1"; # Pas aan naar jouw AWS regio
  relayHost = "email-smtp.${awsRegion}.amazonaws.com";
in
{
  services.postfix = {
    # ...
    hostname = "home.toorren.net"; # Pas aan naar jouw hostname
    # ...
  };
}
```

### Module importeren

Voeg de module toe aan je host configuratie (bijv. `hosts/malandro/configuration.nix`):

```nix
{
  imports = [
    ../../modules/postfix.nix
    # ... andere modules
  ];
}
```

## Stap 5: NixOS rebuild

```bash
# Voor lokale machine
sudo nixos-rebuild switch --flake .#hostname

# Voor remote machine (bijv. malandro)
sudo nixos-rebuild switch --flake .#malandro --target-host malandro
```

## Stap 6: Testen

### Status controleren

```bash
# Check of postfix draait
systemctl status postfix

# Check of SASL setup succesvol was
systemctl status postfix-sasl-setup

# Controleer de postmap database
sudo ls -la /run/agenix/postfix-sasl-password*
```

Je zou moeten zien:
- `/run/agenix/postfix-sasl-password` (het plaintext secret)
- `/run/agenix/postfix-sasl-password.db` (de postmap database)

### Test mail versturen

**Eenvoudige test:**

```bash
echo "Test email body" | sendmail -v jouw-geverifieerde-email@voorbeeld.nl
```

**Uitgebreidere test met headers:**

```bash
sendmail -v jouw-geverifieerde-email@voorbeeld.nl << 'EOF'
From: noreply@toorren.net
To: jouw-geverifieerde-email@voorbeeld.nl
Subject: Postfix AWS SES test

Dit is een test email verstuurd via Postfix met AWS SES relay.
EOF
```

**Let op:** In SES Sandbox mode moet je zowel de FROM als TO adressen verifiëren!

### Logs controleren

```bash
# Postfix logs (realtime)
sudo journalctl -u postfix -f

# SASL setup logs
sudo journalctl -u postfix-sasl-setup

# Postfix mail queue bekijken
sudo postqueue -p

# Specifieke mail opzoeken (vervang QUEUE_ID met ID uit logs)
sudo postcat -vq QUEUE_ID
```

## Troubleshooting

### Error: "SASL authentication failed"

**Oorzaken:**
- Verkeerde username/password
- Verkeerd formaat in secrets bestand
- Verkeerde regio endpoint

**Oplossing:**
```bash
# Check het gedecrypte secret (voorzichtig met deze output!)
sudo cat /run/agenix/postfix-sasl-password

# Het moet exact dit formaat hebben:
# [email-smtp.REGION.amazonaws.com]:587 USERNAME:PASSWORD

# Herstart postfix na correctie
sudo systemctl restart postfix-sasl-setup
sudo systemctl restart postfix
```

### Error: "Relay access denied"

**Oorzaak:** Postfix probeert mail te relayeren maar heeft geen toegang.

**Oplossing:**
```bash
# Check postfix configuratie
sudo postconf | grep relay

# Moet bevatten:
# relayhost = [email-smtp.REGION.amazonaws.com]:587
```

### Error: "TLS handshake failed"

**Oorzaak:** TLS certificaat problemen.

**Oplossing:**
```bash
# Check of CA certificates aanwezig zijn
ls -la /etc/ssl/certs/ca-certificates.crt

# Herstart met TLS debugging
# Uncomment in modules/postfix.nix:
# smtp_tls_loglevel = "1";

sudo nixos-rebuild switch --flake .#hostname
sudo journalctl -u postfix -f
```

### Error: "User email address is not verified"

**Oorzaak:** Je bent in SES Sandbox mode en het TO adres is niet geverifieerd.

**Oplossing:**
- Verifieer het TO email adres in AWS SES Console
- OF vraag Production Access aan om uit de sandbox te komen

### Mail komt niet aan

**Check:**

1. **Postfix queue:**
   ```bash
   sudo postqueue -p
   ```
   Lege queue betekent dat mail verstuurd is naar AWS.

2. **Postfix logs:**
   ```bash
   sudo journalctl -u postfix | grep "status=sent"
   ```
   Zou `relay=email-smtp.REGION.amazonaws.com` moeten tonen.

3. **AWS SES Console:**
   - Ga naar SES → Email sending statistics
   - Check "Sent", "Bounces", "Complaints"

4. **Spam folder:**
   - Check de spam folder van de ontvanger
   - Mogelijk moet je SPF/DKIM/DMARC configureren

## AWS SES Limieten

| Limiet | Waarde (Sandbox) | Waarde (Productie) |
|--------|------------------|-------------------|
| Emails per dag | 200 | Verhoogbaar (start bij 50.000) |
| Emails per seconde | 1 | Verhoogbaar (start bij 14) |
| Message size | 10 MB | 10 MB |
| Ontvangers | Alleen geverifieerd | Iedereen |

## SPF, DKIM, DMARC configuratie

### SPF Record

Voeg toe aan je DNS (TXT record voor `toorren.net`):

```
v=spf1 include:amazonses.com ~all
```

### DKIM

AWS SES genereert automatisch DKIM keys bij domein verificatie. Voeg de DNS records toe die AWS toont.

### DMARC

Optioneel, maar aanbevolen (TXT record voor `_dmarc.toorren.net`):

```
v=DMARC1; p=quarantine; rua=mailto:postmaster@toorren.net
```

## Nuttige commando's

```bash
# Postfix configuratie bekijken
sudo postconf -n

# Postfix queue wissen (na testen)
sudo postsuper -d ALL

# Mail queue opnieuw versturen
sudo postqueue -f

# Specific mail uit queue verwijderen
sudo postsuper -d QUEUE_ID

# Postfix herladen (na config wijzigingen)
sudo systemctl reload postfix

# Postfix volledig herstarten
sudo systemctl restart postfix
```

## Referenties

- [AWS SES SMTP documentatie](https://docs.aws.amazon.com/ses/latest/dg/send-email-smtp.html)
- [Postfix SASL configuration](http://www.postfix.org/SASL_README.html)
- [AWS SES regio's](https://docs.aws.amazon.com/general/latest/gr/ses.html)
