# Tasks

## 1. nginx: afgeleide map per site

- [x] 1.1 `modules/ai-blocklist/default.nix`: optie `allowAgents` (`listOf (strMatching "[A-Za-z0-9._-]+")`, default `[ ]`) in de site-submodule; voor sites met niet-lege `allowAgents` een `map $http_user_agent $ai_bot_<vhost>` met `default $ai_bot;` en de vrijgegeven namen (`lib.escapeRegex`) → `0` in `commonHttpConfig` na de include, en `blockIf` per site op die variabele (design, besluit 1); header-commentaar van de module bijwerken; verificatie: `nix build .#nixosConfigurations.malandro.config.system.build.toplevel` slaagt
- [x] 1.2 Zonder `allowAgents` geen verschil; verificatie: vóór het zetten van cckafe.com is de gegenereerde `nginx.conf` van malandro identiek aan die van `main` (`diff` van beide builds)

## 2. robots.txt: toegestane bots weglaten

- [x] 2.1 `allowAgents` toevoegen aan `SITES_JSON` en in `update-ai-blocklist.py` filteren vóór `missing` in `render_robots`, met een waarschuwing in het log voor een naam die niet in de botlijst staat (design, besluit 2); verificatie: `render_robots` met een tijdelijke webroot in de scratchpad en `allowAgents = ["facebookexternalhit"]` levert een bestand zonder `User-agent: facebookexternalhit`, en zonder `allowAgents` mét die regel

## 3. cckafe.com en documentatie

- [x] 3.1 `hosts/malandro/configuration.nix`: `"cckafe.com".allowAgents = [ "facebookexternalhit" ];` met een korte reden in commentaar; verificatie: malandro bouwt en de gegenereerde `nginx.conf` bevat `$ai_bot_cckafe_com` in de map én in de `if` van de cckafe.com-vhost, en bij de andere vhosts nog `$ai_bot`
- [x] 3.2 `docs/ai-blocklist.md`: optie `allowAgents` beschrijven, kolom/regel voor cckafe.com in de sitetabel, de valkuil over `facebookexternalhit` herschrijven (per site via `allowAgents`, niet via `ALLOWLIST`) en de Facebook-cache noemen; verificatie: de documentatie noemt de optie en de commando's uit 4.1

## 4. Integratie op malandro

- [x] 4.1 Na `sudo nixos-rebuild switch` (door de gebruiker) en `sudo systemctl start ai-blocklist.service`: `curl -s -o /dev/null -w '%{http_code}\n' -A 'facebookexternalhit/1.1' https://cckafe.com/` → 200; zelfde UA op `https://toorren.net/` → 403; `-A 'GPTBot/1.2' https://cckafe.com/` → 403; `curl -s https://cckafe.com/robots.txt | grep -i facebookexternalhit` → geen uitvoer; `curl -s https://toorren.net/robots.txt | grep -i facebookexternalhit` → wel
- [ ] 4.2 Facebook Sharing Debugger (`https://developers.facebook.com/tools/debug/`) op `https://cckafe.com/`, "Scrape Again"; verificatie: de debugger toont respons 200 en de OG-afbeelding

## Workflow follow-up

- Change archiveren en bean `nixos-bg0o` afsluiten zodra 4.1 en 4.2 groen zijn.
