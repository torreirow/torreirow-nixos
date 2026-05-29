## ADDED Requirements

### Requirement: msmtp als sendmail-vervanging beschikbaar
Het systeem SHALL msmtp installeren en configureren als `sendmail`-vervanging op lobos, zodat tools die `/usr/bin/sendmail` of `mail` aanroepen automatisch via msmtp versturen.

#### Scenario: Mail sturen via mail commando
- **WHEN** gebruiker `echo "Bericht" | mail -s "Onderwerp" ontvanger@example.com` uitvoert
- **THEN** mail wordt verstuurd via AWS SES zonder foutmelding

#### Scenario: Mail sturen via msmtp direct
- **WHEN** gebruiker `echo -e "Subject: Test\n\nBericht" | msmtp ontvanger@example.com` uitvoert
- **THEN** mail wordt verstuurd via AWS SES

### Requirement: Afzenderadres lobos@toorren.net
Het systeem SHALL alle uitgaande mails versturen met `From: lobos@toorren.net`, ongeacht de aanroepende gebruiker.

#### Scenario: Afzender in ontvangen mail
- **WHEN** een mail verstuurd wordt via msmtp op lobos
- **THEN** heeft de ontvangen mail `From: lobos@toorren.net` in de header

### Requirement: AWS SES relay via eu-central-1
Het systeem SHALL mails relay via `email-smtp.eu-central-1.amazonaws.com` poort 587 met STARTTLS en SASL authenticatie.

#### Scenario: Verbinding met AWS SES
- **WHEN** msmtp een mail verstuurt
- **THEN** maakt het verbinding met `email-smtp.eu-central-1.amazonaws.com:587` via STARTTLS

#### Scenario: Authenticatie mislukt
- **WHEN** de AWS SES credentials onjuist zijn
- **THEN** geeft msmtp een duidelijke foutmelding terug

### Requirement: Credentials veilig opgeslagen via agenix
Het systeem SHALL het AWS SES SMTP wachtwoord opslaan in een agenix-encrypted secret bestand, niet in plaintext in de NixOS configuratie.

#### Scenario: Secret beschikbaar voor msmtp
- **WHEN** nixos-rebuild switch is uitgevoerd
- **THEN** is het decrypted secret leesbaar voor de msmtp passwordeval configuratie
