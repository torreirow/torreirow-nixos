# Tasks

## 1. Opties

- [ ] 1.1 Voeg `limits.kinds` toe (`attrsOf (submodule { perHour; perDay; })`) met
      defaults `contact = { 3; 10; }` en `signup = { 30; 80; }`; houd `totalPerDay`
      (nieuwe default 150) en verwijder de impliciete per-ontvanger-rem uit de
      documentatie zodra de buckets hem vervangen.
- [ ] 1.2 Voeg `limits.perIpPerDay` toe (default 8) en een `stateDir/salt`
      (mode 0400, eenmalig aangemaakt met `openssl rand -hex 16` of `pkgs.openssl`).
- [ ] 1.3 Verhoog `totalPerDay` naar 150 in `hosts/malandro/configuration.nix` als de
      default daarvan afwijkt.

## 2. PHP-script

- [ ] 2.1 Lees `soort` (whitelist `contact`/`signup`, default `contact`) en kies de
      bucket uit `limits.kinds`.
- [ ] 2.2 Houd regels bij als `{t, to, k, ip, d}`: `to` = ontvanger, `k` = soort,
      `ip` = `hash(salt + remote_addr)`, `d` = `hash(email + soort + meetup)`.
- [ ] 2.3 Tel per bucket (`perHour`, `perDay`), per IP (`perIpPerDay`) en over alles
      (`totalPerDay`); bij overschrijding 429 met de bestaande melding en een
      `error_log`-regel met de reden.
- [ ] 2.4 Sla de mail over bij een bestaande `d`-hash binnen 24 uur en antwoord 200.
- [ ] 2.5 Voeg de kill switch toe: bestaat `${stateDir}/disabled`, dan 503.
- [ ] 2.6 Zet `soort` en `meetup` in de `error_log`-regels bij een weigering, zonder
      naam, e-mail of bericht mee te loggen.

## 3. Verificatie

- [ ] 3.1 `sudo nixos-rebuild switch --flake .#malandro` en controleren dat de module
      bouwt en de pool herstart.
- [ ] 3.2 Regen-test met `curl` vanaf één IP: 4× `contact` in een uur → de 4e geeft
      429; 31× `signup` → de 31e geeft 429; 9× POST → de 9e geeft 429.
- [ ] 3.3 Zonder `soort`-veld: gedrag identiek aan voor de wijziging (3/10).
- [ ] 3.4 Twee keer dezelfde `email` + `meetup` binnen 24 uur: tweede keer 200 zonder
      mail (controleren in `ratelimit.json` en postfix-log).
- [ ] 3.5 `disabled` aanmaken → 503; verwijderen → weer 200.
- [ ] 3.6 Controleren dat `ratelimit.json` geen leesbare IP-adressen bevat.

## Workflow follow-up

- Site-change `meetup-signup-form` (cckafe-website) pas deployen nadat deze module op
  malandro draait.
- Documenteer de buckets en de kill switch in `docs/` (of `CONTRIBUTING.md` van de
  sites) zodat een beheerder ze zonder de code kan vinden.
