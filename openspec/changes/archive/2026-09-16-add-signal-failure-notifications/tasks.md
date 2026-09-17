## 1. `--silent` uit nextcloud-sync

- [x] 1.1 `--silent` uit de vaste argumentenlijst van `mkExecStart` halen in `home/module/nextcloud-sync/default.nix`
- [x] 1.2 Optie `quiet` toevoegen (bool, default `false`) die de vlag desgewenst terugzet
- [x] 1.3 In de module opschrijven waaróm de default omging — de storing van 9-16 september, 419 mislukte runs met alleen "Failed to start" in de journal
- [x] 1.4 Optie `onFailure` (listOf str, default `[]`) toevoegen en als `Unit.OnFailure` doorgeven
- [x] 1.5 Geverifieerd na de switch: `systemctl --user cat nextcloud-sync-docs.service` bevat 0 treffers voor `--silent`

## 2. Meldkanaal kiezen

- [x] 2.1 Vastgesteld dat het rustic-patroon niet bruikbaar is: `ss -tlnp` op malandro toont `LISTEN 127.0.0.1:8088`, en een TCP-probe naar poort 8088 vanaf lobos faalt
- [x] 2.2 Home Assistant als route gekozen: `https://homeassistant.toorren.net` → HTTP 200 vanaf lobos, en `notify.signal_maria` staat in `/api/services` (naast `notify.wouter`, Telegram)
- [x] 2.3 SSH-hop naar malandro afgewogen en verworpen: leunt op de rbw-agent, die gelockt kan zijn — dan faalt juist de meldingsweg. Vastgelegd in design.md
- [x] 2.4 Geldigheid van `secrets/ha-token.age` geverifieerd met `ragenx -d` (193 tekens, HA `/api/` → HTTP 200). De secret bestond al maar werd nergens gebruikt

## 3. Module `notify-signal`

- [x] 3.1 `home/module/notify-signal/default.nix` aanmaken met opties `enable`, `homeAssistantUrl`, `service`, `tokenFile`
- [x] 3.2 Template-unit `notify-signal@.service` die `%i` als naam van de falende unit doorgeeft
- [x] 3.3 Bericht opbouwen met hostnaam, unitnaam, de laatste vijf journalregels van die unit, en het commando om verder te kijken
- [x] 3.4 `--fail-with-body` op de curl, zodat een geweigerde melding (HTTP 400/401/500) de unit laat falen in plaats van stilzwijgend te slagen
- [x] 3.5 Module importeren in `flake.nix` (modulelijst van `homeConfigurations."wtoorren@linuxdesktop"`)

## 4. Secret op lobos

- [x] 4.1 `age.secrets.ha-token` toevoegen aan `hosts/lobos/lobos-secrets.nix` met expliciet `path = "/run/secrets/ha-token"`, owner `wtoorren`, mode `0400`
- [x] 4.2 Geverifieerd na de switch: `/run/secrets/ha-token` bestaat als symlink naar `/run/keys/wouter/ha-token` en is leesbaar als `wtoorren` (194 bytes)

## 5. Aanhaken

- [x] 5.1 `onFailure` toevoegen aan `home/module/remarkable-sync/default.nix` (zelfde patroon als nextcloud-sync)
- [x] 5.2 `services.notify-signal.enable = true` en `onFailure = [ "notify-signal@%N.service" ]` op beide syncs in `home/linux-desktop.nix`
- [x] 5.3 Geverifieerd dat `%N` correct expandeert: `OnFailure=notify-signal@nextcloud-sync-docs.service` en `notify-signal@remarkable-sync.service`

## 6. Testen

- [x] 6.1 Echte melding verstuurd via `systemctl --user start notify-signal@TEST-geen-echte-storing.service` — unit exit 0, en **de gebruiker bevestigde dat het Signal-bericht binnenkwam**
- [x] 6.2 Foutdetectie bewezen tegen een niet-bestaande notify-dienst: `curl -s` gaf exit 0 bij HTTP 400 (oud gedrag, stille fout), `curl --fail-with-body` gaf exit 22 mét de respons (nieuw gedrag)
- [x] 6.3 `home-manager switch` draaien zodat `--fail-with-body` ook daadwerkelijk in de geïnstalleerde unit zit (gebouwd en getest, nog niet geactiveerd)
- [x] 6.4 Na die switch één keer verifiëren dat een geweigerde melding de unit laat falen — bijvoorbeeld door tijdelijk `service = "bestaat_niet"` te zetten, of gewoon afwachten tot de eerste echte storing

**Stand 2026-09-16.** 6.3 geverifieerd na de switch: het geïnstalleerde script
(`/nix/store/…-notify-signal`) bevat `curl -sS --fail-with-body` en nul treffers voor de oude
`curl -s --max-time`. 6.4 is *niet* end-to-end door de unit heen getest -- dat zou tijdelijk een
verkeerde `service`-naam en een extra rebuild vereisen. Wat wél gemeten is: exact deze
curl-aanroep gaf tegen een niet-bestaande notify-dienst exit 22 met de HTTP-400-respons, terwijl
de oude vorm exit 0 gaf. Het foutpad (`exit 1` na een mislukte POST, en `exit 1` bij een
onleesbaar token) staat zichtbaar in het geïnstalleerde script. De eerste echte storing is de
resterende test.

## 7. Documentatie

- [x] 7.1 `CHANGELOG.md` bijgewerkt onder `## NEXT VERSION` — `### Added` voor notify-signal, `### Fixed` voor het `--silent`-defect
- [x] 7.2 Overwegen of hetzelfde vangnet op malandro nodig is; daar bestaat al `rustic-notify@`, maar alleen op de backup-units
  → **Besloten: buiten scope.** malandro heeft met `rustic-notify@` al een vangnet op de
  backup-units, en kan de signal-cli API rechtstreeks bereiken -- daar is deze module niet voor
  nodig. Wil je het vangnet daar breder trekken dan de backup-units, dan is dat een eigen change.
