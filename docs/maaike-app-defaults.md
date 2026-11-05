# App-standaarden van Maaike (mpenzi)

Wouter kan de standaardinstellingen van Maaikes apps met één commando terugzetten. Maaike voert
daarna hooguit een wachtwoord in of scant een QR-code. OpenSpec-change `maaike-app-defaults`
(gearchiveerd), epic `nixos-kzxu`.

```bash
# vanaf lobos
ssh wtoorren@10.77.0.3 sudo herstel-app maaike nextcloud     # of: bitwarden zapzap smplayer spotify signal all
```

## Per app

| App       | Standaard                                       | Herstel doet                   | Maaike daarna                         |
|-----------|-------------------------------------------------|--------------------------------|---------------------------------------|
| Nextcloud | `nxc.toorren.net`, `mtoorren`, `~/Nextcloud` ↔ `/` | seed terug                   | inloggen via de browser (gebruikersnaam staat al ingevuld; getest 2026-11-05) |
| Bitwarden | server `https://vw.toorren.net`                 | seed terug (kluis lokaal weg)  | e-mail + master-wachtwoord            |
| ZapZap    | instellingen uit de gouden config               | seed terug (sessie blijft)     | niets; zo nodig QR-code scannen       |
| SMPlayer  | hardware-decodering (`hwdec=auto`)              | seed terug                     | niets                                 |
| Spotify   | login via agenix (`spotify-maaike.age`)         | symlink naar het secret        | niets                                 |
| Signal    | geen (config bevat een sleutel)                 | alleen uitleg                  | opnieuw koppelen met QR-code          |
| Firefox   | policy: Bitwarden + uBlock Origin               | altijd actief                  | Bitwarden-extensie inloggen           |
| Chrome    | policy: Bitwarden + uBlock Origin Lite          | altijd actief                  | Bitwarden-extensie inloggen           |

Thunderbird: policy voor offline-synchronisatie staat er. Het Gmail-account (OAuth) komt later en
blijft handwerk.

## Hoe het werkt

Er zijn drie mechanismen:

1. **Policy** (Firefox, Chrome, Thunderbird) in `hosts/mpenzi/apps.nix`. Dit is altijd juist en
   Maaike kan de extensies niet weghalen.
2. **agenix met `path`** (Spotify), zelfde patroon als `spotifywto` op lobos. Een deploy zet het
   bestand terug.
3. **Seed + herstel** (Nextcloud, Bitwarden, ZapZap, SMPlayer):
   - `home/profiles/maaike/seeds.nix` bevat de lijst en het script `seed-apps`.
   - De home-manager-activatie van maaike (`home-manager-maaike.service`, bij boot en bij elke
     switch) kopieert een bestand alleen als het ontbreekt. Het wordt een gewoon, schrijfbaar
     bestand van haar, geen store-link.
   - `herstel-app` stopt de app (`pkill -u maaike`), bewaart de oude versie als
     `*.bak-<datum>` en draait hetzelfde script met `--force`.

Bestanden: `modules/maaike-apps.nix` (`toorren.maaike.{enable,spotifyPrefs}`),
`home/profiles/maaike/{default,seeds}.nix`, `home/profiles/maaike/defaults/`, test
`modules/maaike-apps_vmtest.nix`.

Geen Plasma-instellingen in dit profiel. Die blijven de `/etc/xdg`-defaults uit
`hosts/mpenzi/plasma.nix`, die Maaike zelf mag aanpassen.

## Gouden config vastleggen

De standaarden zijn niet geraden. Wouter richt een app één keer in met Maaike (RustDesk) en legt
het resultaat vast:

```bash
scripts/vastleggen-app-defaults.sh            # vanaf lobos, in de repo; vraagt sudo op mpenzi
```

- Het script haalt `nextcloud.cfg` en `ZapZap.conf` op en laat regels met
  token/password/cookie/session weg.
- Per bestand toont het een diff met `home/profiles/maaike/defaults/` en schrijft het pas na `j`.
- Daarna: committen en mpenzi deployen. Bestaande bestanden bij Maaike blijven staan; met
  `herstel-app` gaat de nieuwe standaard erin.

Niet vastgelegd:

- **Spotify-prefs**: die bevatten een login-token en gaan via ragenx:
  `ssh wtoorren@10.77.0.3 sudo cat /home/maaike/.config/spotify/prefs | (cd secrets && ragenx -e spotify-maaike.age)`.
- **Bitwarden `data.json`**: bevat de kluis. De seed is een minimale `data.json` in `seeds.nix`;
  het formaat komt uit bitwarden-desktop 2026.8.0, `stateVersion` 83.
- **Signal**.

## Spotify

- `secrets/spotify-maaike.age` (recipients `users ++ [ mpenzi ]`) wordt
  `/home/maaike/.config/spotify/prefs`, owner maaike, 0600.
- Zonder het bestand bouwt mpenzi gewoon, met een warning (`builtins.pathExists` in
  `hosts/mpenzi/configuration.nix`).
- Spotify kan de symlink bij het opslaan vervangen door een gewoon bestand; `herstel-app maaike
  spotify` legt hem terug.

## Testen

```bash
nix build .#checks.x86_64-linux.maaike-apps -L
```

De test controleert:

- seeds na de eerste activatie;
- een tweede activatie laat een gewijzigd bestand staan;
- herstel-app zet de standaard terug met een `.bak-*`;
- alleen de processen van maaike worden gestopt;
- foutmelding bij een onbekende app of gebruiker;
- uitleg bij signal en bij spotify zonder secret.
