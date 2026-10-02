# Design

## Context

- Lockscreen = hyprlock v0.9.5, geconfigureerd via home-manager (`programs.hyprlock` in
  `home/hyprland/hyprlock.nix`, standalone HM-config `wtoorren@linuxdesktop`). Gestart door
  hypridle (`lock_cmd`, `before_sleep_cmd = loginctl lock-session`) en door de bindings
  `SUPER+L` / `SUPER+SHIFT+L` (vergrendelen + `systemctl suspend`).
- `/etc/pam.d/hyprlock` bevat alleen `pam_unix`, door `security.pam.services.hyprlock.fprintAuth =
  false` in `hosts/lobos/hyprland.nix`.
- `services.fprintd.enable = true`, Synaptics-sensor, 4 vingers geregistreerd voor `wtoorren`.
  fprintd start op aanvraag over D-Bus en stopt zichzelf na ~30s zonder gebruik.
- lobos kent alleen s2idle (zie `power-management.nix`). Daar draait al een resume-hack voor
  `ath11k_pci`, dus "hardware komt niet netjes terug na resume" is hier een bekend patroon.

## Goals / Non-Goals

**Goals:**
- Vingerafdruk en wachtwoord parallel op het lockscreen, zonder blokkade (zie spec).

**Non-Goals:**
- Vingerafdruk voor sudo, greetd, polkit of andere PAM-services.
- Visuele feedback over de sensor-status.
- Wijzigingen aan fprintd zelf of aan de registratie van vingers.

## Decisions

### 1. Native hyprlock-fingerprint, niet `pam_fprintd`
`auth."fingerprint:enabled" = true` laat hyprlock zelf over D-Bus met fprintd praten, naast de
PAM-conversatie voor het wachtwoord (`auth."pam:enabled" = true`, de default, expliciet gezet).
- *Alternatief: `fprintAuth = true` in PAM.* Afgewezen: `pam_fprintd` blokkeert sequentieel tot
  vinger of timeout. Dat was precies de reden om het uit te zetten.
- *Alternatief: `pam_fprintd` met korte `timeout=`/`max-tries=`.* Afgewezen: dat verkort de wachttijd
  alleen en heft hem niet op, en het blijft een volgorde in plaats van parallel.

### 2. PAM `fprintAuth = false` blijft staan
Met native fingerprint én `pam_fprintd` zouden twee clients om dezelfde sensor strijden, en komt
de PAM-blokkade terug. De regel blijft dus staan. Alleen het commentaar verandert ("vingerafdruk
loopt via hyprlock's eigen D-Bus-pad, niet via PAM"). Een commentaarwijziging levert geen andere
derivation op, dus voor deze regel is geen `nixos-rebuild` nodig.

### 3. Statisch icoon onder het veld, geen `$FPRINTPROMPT`, geen eigen meldingen
Een statisch `label` met het Nerd-Font-glyph 󰈷 (U+F0237, `nf-md-fingerprint`) in `JetBrainsMono Nerd
Font`, **onder** het invoerveld (`position = "0, -110"`), Gruvbox fg4. Het icoon zegt "dit kan", een
statustekst blijft ongewenst. Iteraties op verzoek van de user: onder het veld → in de
`placeholder_text` → rechts in het veld → weg → en uiteindelijk terug **onder** het veld (de user wilde
het niet in het tekstvak). De placeholder- en fail-teksten rouleren (decision 6).
Er komt geen label met `$FPRINTPROMPT`. `fingerprint:ready_message` en `present_message` worden
niet ingesteld: zonder label dat ze toont, zijn ze onzichtbaar. Een mislukte vinger kan de
`fail_text` in het invoerveld triggeren. De roterende fail-teksten (decision 6) zijn neutraal
geformuleerd en passen bij beide methoden.

### 4. Resume-gedrag: eerst meten, dan pas bouwen
Er wordt niet vooraf een resume-hook gebouwd. Taak 3 test vergrendelen → suspend → resume → vinger.
Faalt dat, dan wordt de oorzaak eerst uit `journalctl -u fprintd` / de hyprlock-output gehaald en
pas dan een fix gekozen (bijvoorbeeld fprintd herstarten bij resume, analoog aan `wifi-resume`).
Die fix wordt dan als extra taak toegevoegd.

### 5. Resultaat resume-test: hyprlock 0.9.5 claimt de sensor maar één keer → lokale patch
Tests 2.4 en 3.2 faalden. De oorzaak komt uit de journal en uit `src/auth/Fingerprint.cpp` (0.9.5):
`claimDevice()` logt bij een fout alleen een warning en probeert het nooit opnieuw. Fingerprint
blijft dan dood voor die hele lock-sessie. Het wachtwoord werkt wel.

- **2.4 (snel opnieuw vergrendelen, niet de wachttijd):** na een wachtwoord-unlock tijdens een lopende
  verify doet de Synaptics-close er tot ~70s over (`Error closing device after disconnect: transfer
  timed out`). Een nieuwe hyprlock binnen dat venster krijgt `Claim: Device was already claimed`.
- **3.2 (vergrendelen + suspend):** fprintd's idle-timer (30s na de vorige unlock) liep tijdens
  s2idle stil en vuurde direct na de resume (`Deactivated successfully` op hetzelfde moment als de
  wake). De claim van hyprlock raakte een fprintd die net afsloot.

Fix (keuze user):
- **Overlay `overlays/hyprlock.nix`** met patch `overlays/patches/hyprlock-fprint-reclaim.patch` op 0.9.5:
  (a) bij wake (`PrepareForSleep false`) verify stoppen, releasen, device-proxy weggooien en opnieuw
  claimen, ongeacht de `verifying`-vlag. Port van upstream PR #1049 (open, nog niet gemerged; de PR
  zelf is tegen `main` geschreven en past niet op 0.9.5). (b) Een mislukte `Claim` wordt opnieuw
  geprobeerd met exponentiële backoff (0,5s → max 30s per poging, 12 pogingen ≈ 3,5 min, genoeg
  voor de ~70s close-hang). De proxy wordt in een timer weggegooid, niet in zijn eigen
  reply-callback (use-after-free).
- **fprintd `--no-timeout`**: haalt de idle-exit-race helemaal weg. fprintd blijft draaien (~5 MB).
- De overlay staat in de lobos-NixOS- **én** de HM-overlays: `hyprlock` staat in allebei op PATH.
- *Alternatief: alleen `--no-timeout`.* Afgewezen: lost 2.4 niet op.
- *Alternatief: upgraden naar 0.9.6.* Afgewezen: issue #1074 meldt dat snel opnieuw vergrendelen
  daar juist slechter werkt.
- *Onderhoud:* zodra nixpkgs hyprlock bumpt, kan de patch niet meer passen. Dat zie je als buildfout,
  niet als stil falen. Verwijder de patch zodra upstream een gelijkwaardige fix heeft gemerged.

### 6. Roterende lock-teksten: per vergrendeling, via een gesourced bestand
De user wil dat placeholder en fail_text rouleren, in een professionele DevOps/Nix-toon (niet ludiek).
hyprlock 0.9.5 leest `placeholder_text`/`fail_text` één keer bij de start (`formatString` kent
`$USER`/`$ATTEMPTS`/`$FAIL`, maar geen `cmd[update:N]`). Rouleren *tijdens* het vergrendeld zijn kan dus
niet. Wel: **per vergrendeling.**
- `hyprlock.conf` doet `source = ~/.local/state/hyprlock/texts.conf` (dankzij `importantPrefixes` vóór de
  widgets, anders zijn de hyprlang-variabelen nog niet gedefinieerd) en gebruikt `$LOCK_PLACEHOLDER` /
  `$LOCK_FAIL`.
- Het script `hyprlock-rotate-texts` kiest willekeurig één tekst per soort uit Nix-lijsten en schrijft
  het bestand atomair (tmp + `mv`). Het draait bij de HM-activatie (zodat het bestand er altijd is) en
  via hypridle's `on_unlock_cmd`. Dat hangt aan Hyprland's lock-notificatie, dus geldt voor álle routes
  (SUPER+L, SUPER+SHIFT+L, idle, wayle).
- *Alternatief: wrapper om hyprlock.* Afgewezen: faalt de wrapper, dan start er geen lockscreen.
- *Alternatief: label met `cmd[update:N]` over het veld.* Afgewezen: verdwijnt niet bij het typen en
  overlapt de stippen.
- Faalveiligheid: hyprlock negeert configfouten ("Proceeding ignoring faulty entries"). Ontbreekt het
  bestand, dan zie je hooguit de letterlijke variabelenaam, en vergrendelen blijft werken.
- `~/.local/state` in plaats van `~/.cache`, zodat een cache-opschoning het bestand niet weghaalt.

## Risks / Trade-offs

- [Synchrone `VerifyStop`/`Release` bij wake op een hangende sensor kan de UI tot de D-Bus-timeout
  (25s) blokkeren] → Gelijk aan upstream PR #1049. Het wachtwoord blijft daarna gewoon werken.

- [Sensor-claim overleeft s2idle niet] → Taak 3 test dit expliciet. Wachtwoord blijft het vangnet.
- [`fail_text` bij een mislukte vinger] → Opgelost: de roterende fail-teksten zijn neutraal (decision 3/6).
- [fprintd stopt na ~30s idle] → hyprlock houdt de claim zolang het lockscreen openstaat. Taak 2
  verifieert dat de vinger ook na >30s vergrendeld nog werkt.

## Migration Plan

1. `home-manager switch --flake .#wtoorren@linuxdesktop ...` (de user draait dit zelf).
2. Een nieuwe hyprlock-instantie leest de config. Er is geen herstart van de sessie nodig.
3. Rollback: `fingerprint:enabled` weghalen en opnieuw `home-manager switch`, of de vorige
   HM-generatie activeren.
