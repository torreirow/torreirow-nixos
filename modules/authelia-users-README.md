# Authelia User Management

## Setup

De Authelia user management is nu geactiveerd. Volg deze stappen om gebruikers toe te voegen:

## 1. Genereer een password hash

Gebruik één van deze methoden:

### Methode A: Als authelia al draait op je systeem
```bash
authelia crypto hash generate argon2 --password 'jouwwachtwoord'
```

### Methode B: Via nix-shell (als authelia nog niet draait)
```bash
nix-shell -p authelia --run "authelia crypto hash generate argon2 --password 'jouwwachtwoord'"
```

De output ziet er zo uit:
```
Digest: $argon2id$v=19$m=65536,t=3,p=4$c29tZXNhbHQ$HashValue...
```

Kopieer de hele string (vanaf `$argon2id$...`)

## 2. Voeg gebruikers toe aan je configuratie

Voeg dit toe aan je `hosts/malandro/configuration.nix`:

```nix
services.authelia.users = [
  {
    username = "wouter";
    displayname = "Wouter van der Toorren";
    email = "wouter@toorren.net";
    passwordHash = "$argon2id$v=19$m=65536,t=3,p=4$JOUW_HASH_HIER";
    groups = [ "admins" "users" "monitoring" ];
    disabled = false;
  }
];
```

## 3. Rebuild je systeem

```bash
sudo nixos-rebuild switch
```

## Groepen en Toegang

De volgende groepen zijn geconfigureerd in `authelia.nix`:

### `admins`
- Volledige toegang tot alle `*.toorren.net` subdomeinen
- Vereist two-factor authenticatie

### `monitoring`
- Toegang tot `grafana.toorren.net`
- Toegang tot `prometheus.toorren.net`
- Vereist two-factor authenticatie

### `users`
- Toegang tot `docs.toorren.net` (Paperless)
- Toegang tot `contacts.toorren.net` (Baikal web UI)
- Vereist two-factor authenticatie

### `network`
- Toegang tot `wg.toorren.net` (WireGuard management)
- Vereist two-factor authenticatie

## Nieuwe groepen toevoegen

Om nieuwe groepen toe te voegen, pas de `access_control` sectie aan in `modules/authelia.nix`:

```nix
# Voorbeeld: media groep voor jellyfin
{
  domain = "jellyfin.toorren.net";
  policy = "two_factor";
  subject = [ "group:media" ];
}
```

## Gebruiker uitschakelen

Zet `disabled = true;` voor een gebruiker:

```nix
{
  username = "olduser";
  # ... andere velden ...
  disabled = true;
}
```

## Tips

1. **Altijd twee-factor gebruiken**: Alle groepen vereisen 2FA voor betere beveiliging
2. **Email adressen**: Zorg dat email adressen correct zijn voor password resets
3. **Groepen combineren**: Gebruikers kunnen in meerdere groepen zitten
4. **Test eerst**: Maak eerst een test-gebruiker voordat je productiemachines configureert

## Troubleshooting

### Gebruiker kan niet inloggen
- Check of de password hash correct is gegenereerd
- Controleer of `disabled = false`
- Verify dat de gebruiker in een groep zit met toegang tot de applicatie

### Service start niet
```bash
sudo journalctl -u authelia-main -n 50
```

### Users database bekijken
```bash
cat /var/lib/authelia-main/users_database.yml
```
