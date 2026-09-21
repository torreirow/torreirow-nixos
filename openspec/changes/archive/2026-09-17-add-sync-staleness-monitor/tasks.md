## 1. Succesmoment vastleggen in nextcloud-sync

- [x] 1.1 In `home/module/nextcloud-sync/default.nix` een `ExecStartPost=` toevoegen die `~/.local/state/nextcloud-sync/last-success-<naam>` aanraakt; systemd draait dat alleen na een geslaagde `ExecStart`
- [x] 1.2 De state-map aanmaken als hij nog niet bestaat (naast de bestaande `ExecStartPre`-logica)
- [x] 1.3 Verifiëren: handmatige geslaagde run → mtime van het stempelbestand is bijgewerkt
- [x] 1.4 Verifiëren: een mislukte run (bijv. met de server onbereikbaar) laat de mtime ongemoeid
- [x] 1.5 Dode `After`/`Wants=network-online.target` uit de unit halen — die target heeft in de user-manager `LoadState=not-found` en doet niets

## 2. Module `staleness-monitor`

- [x] 2.1 `home/module/staleness-monitor/default.nix` aanmaken, opzet gespiegeld op de bestaande home-manager-modules (`normalizePath`-helper voor `~/`)
- [x] 2.2 Opties: `enable`, `checkTime` (`OnCalendar`-waarde), en `watch.<naam>` met `stampFile`, `softMaxAge` (default `24h`), `hardMaxAge` (default `48h`), `readinessCommand` (nullable), `message`
- [x] 2.3 Beslislogica implementeren: leeftijd < soft → stil; soft ≤ leeftijd < hard → alleen melden als `readinessCommand` slaagt (of ontbreekt); leeftijd ≥ hard → altijd melden
- [x] 2.4 Stempelbestand bij activatie aanmaken als het ontbreekt, zodat de teller bij installatie begint en een verse installatie geen onmiddellijke melding geeft
- [x] 2.5 Onleesbaar stempelbestand tijdens een controle laat de service niet falen, maar wordt wel gelogd
- [x] 2.6 Elk item onafhankelijk beoordelen: een falend `readinessCommand` of ontbrekende stempel bij het ene item blokkeert de andere niet
- [x] 2.7a In `home/module/notify-signal/default.nix` het verzendgedeelte lostrekken in een eigen script en naar buiten beschikbaar maken als read-only optie `sendCommand`; de faalmelding bouwt zijn tekst en roept diezelfde verzender aan (zie design, beslissing 7)
- [x] 2.7 Melden via `services.notify-signal.sendCommand`, zodat er één kanaal en één tokenlocatie blijft
- [x] 2.8 Mislukt het versturen, dan eindigt de controle met een foutstatus en staat de reden in de journal (zelfde les als `--fail-with-body`)
- [x] 2.9 Timer met `OnCalendar` + `Persistent=true`
- [x] 2.10 Module importeren in `flake.nix` (modulelijst van `homeConfigurations."wtoorren@linuxdesktop"`)

## 3. Aansluiten op lobos

- [x] 3.1 In `home/linux-desktop.nix` `services.staleness-monitor` inschakelen met een watch-item voor de Nextcloud-sync
- [x] 3.2 `readinessCommand` voor dat item: `status.php` opvragen en eisen dat het HTTP 200 is **én** dat de JSON `installed:true` en `maintenance:false` bevat — een kale poort- of statuscheck volstaat niet, want de nginx ervoor antwoordt ook als de server uit is (dan met 502)
- [x] 3.3 `onFailure` weghalen bij `services.nextcloud-sync`; de staleness-check neemt die rol over
- [x] 3.4 `onFailure` op `services.remarkable-sync` **laten staan** — die module onderscheidt afwezigheid al zelf, dus een faalmelding betekent daar altijd iets

## 4. Verifiëren

- [x] 4.1 `home-manager switch` en controleren dat timer en service bestaan en de timer een volgend moment heeft
- [x] 4.2 Verse stempel (net gesynct) → controle handmatig starten → geen melding
- [x] 4.3 Stempel kunstmatig terugzetten tot binnen het zachte venster, server bereikbaar → wél een melding
- [x] 4.4 Zelfde stempel, `readinessCommand` kunstmatig laten falen → géén melding
- [x] 4.5 Stempel voorbij de harde drempel, `readinessCommand` falend → alsnog een melding

**Geverifieerd 2026-09-17** door het gegenereerde controlescript rechtstreeks uit de nix-store te
draaien, dus nog vóór een switch. Alle vier de beslistakken gedroegen zich correct:
`0u → binnen de marge, geen melding` · `30u + server bereikbaar → melden` ·
`30u + readiness falend → geen melding` · `60u + readiness falend → alsnog melden`. De twee
meldende gevallen gaven exit 0 (de verzender eindigt met een foutstatus als hij weigert) en de
gebruiker bevestigde dat de Signal-berichten binnenkwamen. Het readiness-commando los getest:
exit 0 tegen de draaiende server.
- [x] 4.6 Verifiëren dat er bij een mislukte sync geen Signal-bericht meer komt van `nextcloud-sync` zelf
- [x] 4.7 Regressie: `remarkable-sync` meldt nog steeds bij een echte fout
- [x] 4.8 `Persistent=true` nakijken bij de eerste meerdaagse afwezigheid: één inhaalcontrole, geen stapel meldingen
  → **Mechanisme staat, empirische bevestiging uitgesteld.** `systemctl --user show` bevestigt
  `Persistent=yes` en `OnCalendar=20:00`, en systemd houdt de laatste trigger bij in
  `~/.local/share/systemd/timers/`. Dat systemd bij meerdere gemiste momenten één inhaalslag doet
  en niet één per gemiste dag is gedocumenteerd gedrag, maar hier pas te zien bij de eerste
  meerdaagse afwezigheid. Tot die tijd is dit een aanname, geen meting -- als er dan tóch een
  stapel meldingen komt, is dat de plek om te kijken.

## 5. Documentatie

- [x] 5.1 `home/module/staleness-monitor/README.md`: wat de twee drempels betekenen, waarom het readiness-commando op inhoud toetst en niet op de statuscode, en waarom dit bewust géén dodemansknop is
- [x] 5.2 Notitie in `docs/` of `CLAUDE.md` over het meetprincipe: bij periodiek werk met geplande downtime meet je het resultaat (is het recent gelukt?) en niet de storing
- [x] 5.3 `CHANGELOG.md` bijwerken onder `## NEXT VERSION`

## 6. Bewust niet in deze change

- [x] 6.1 In de README vastleggen dat automatisch wekken van bobadela1 (wake-on-LAN), een heartbeat naar malandro als echte dodemansknop, en staleness-bewaking op `remarkable-sync` bewust buiten scope vallen — elk een eigen change waard
