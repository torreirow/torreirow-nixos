## Why

Lobos heeft geen manier om mails te versturen vanaf de command line. Voor scripts, cron jobs en handmatig testen is het nuttig om `mail` of `msmtp` direct te kunnen aanroepen. Malandro heeft al een werkende AWS SES relay via Postfix; lobos heeft een lichtgewichter oplossing nodig.

## What Changes

- `programs.msmtp` configureren op lobos als sendmail-vervanging
- Nieuw age-encrypted secret `msmtp-password.age` aanmaken met het AWS SES SMTP wachtwoord
- Afzenderadres instellen op `lobos@toorren.net` (domein al geverifieerd in AWS SES)
- AWS SES relay via `email-smtp.eu-central-1.amazonaws.com:587`

## Capabilities

### New Capabilities

- `lobos-mail-sending`: Mails versturen via msmtp als sendmail-vervanging op lobos, gerouteerd via AWS SES

### Modified Capabilities

## Impact

- `hosts/lobos/configuration.nix` of nieuw `hosts/lobos/mail.nix` — msmtp configuratie
- `secrets/secrets.nix` — nieuw secret `msmtp-password.age` toevoegen voor lobos
- `secrets/msmtp-password.age` — nieuw encrypted secret bestand
