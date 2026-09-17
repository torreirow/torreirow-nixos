## 0. Voorwaarde (hardware)

- [x] 0.1 USB-kabel vervangen door een kabel waarvan vaststaat dat het een datakabel is
- [x] 0.2 Verifiëren dat het flapperen weg is: `journalctl -k --since -10min | grep -cE "new high-speed USB device"` telt 1 (niet tientallen), en `grep -c "error -71"` telt 0
- [x] 0.3 Standby-gedrag vaststellen: hoe lang blijft het apparaat wakker aan de USB, en verdwijnt de gadget bij standby (verwacht: ja)

**Resultaat (2026-09-16):** 0.1/0.2 voldaan — nieuwe kabel, 0 enumeraties, 0 disconnects en
0× `error -71` over 10 minuten, apparaat continu bereikbaar. 0.3: de gadget **verdwijnt
inderdaad volledig** bij standby (gemeten 2026-09-15: interface weg, ping dood, SSH-timeout).
De standby-vertraging staat **niet** in `xochitl.conf` — dat bestand kent geen suspend/idle-sleutel
— het is een instelling in de UI van het apparaat. Bevestigt beslissing 6: afwezigheid is normaal
gedrag en de sync moet er stil op afbreken.

**Bijvangst, relevant voor de backup:** `/home/root/.config/remarkable/xochitl.conf` bevat het
`DeveloperPassword`, de `Passcode` en een cloud-`UserToken`. Dat bestand valt buiten
`~/.local/share/remarkable/xochitl` en komt dus **niet** in de backup — bewust zo houden, anders
belanden die geheimen in Nextcloud.

## 1. Module-skelet

- [x] 1.1 `home/module/remarkable-sync/default.nix` aanmaken, opzet gespiegeld op `home/module/nextcloud-sync/default.nix` (oneshot user-service + timer, `normalizePath`-helper voor `~/`)
- [x] 1.2 Opties definiëren: `enable`, `host` (default `10.11.99.1`), `targetDir` (default `~/Nextcloud/reMarkable`), `interval` (default `2min`), `backup.enable`, `export.enable`, `sshIdentityFile`
- [x] 1.3 `home/module/remarkable-sync/README.md` met de handmatige stappen: sleutel in `~/.ssh-priv/`, `Host remarkable`-blok, en het opnieuw plaatsen van `authorized_keys` na een firmware-update
- [x] 1.4 Module importeren en inschakelen — **correctie:** de *import* hoort in `flake.nix` (modulelijst van `homeConfigurations."wtoorren@linuxdesktop"`, naast `./home/module/nextcloud-sync`); alleen de *configuratie* staat in `home/linux-desktop.nix`. Beide gedaan

## 2. Netwerk: de interface moet vanzelf omhoog komen

NetworkManager laat de gadget-interface op `disconnected` staan (reason 40, carrier wél `on`) en
probeert geen DHCP. Zie design, beslissing 8. **Nooit een kaal `nmcli device connect <interface>`
gebruiken** — dat greep op 2026-09-16 het profiel van de dock-ethernet en legde `eth0` plat.

- [x] 2.1 Declaratief NM-profiel toevoegen in `hosts/lobos/` (`networking.networkmanager.ensureProfiles`), vastgezet op **MAC** `7a:17:67:41:44:36` (niet op interfacenaam — die hangt aan de USB-poort), met `autoconnect = true` en `ipv4.method = auto`
- [x] 2.2 Verifiëren: reMarkable inpluggen → interface krijgt binnen enkele seconden een adres in `10.11.99.0/27` zonder handmatige actie
- [x] 2.3 Regressie: `eth0` (dock) en `wlp2s0` behouden hun eigen profiel en adres; `nmcli device status` toont geen profielwissel
- [x] 2.4 Verifiëren dat het profiel niet activeert op een andere interface (bijv. dock losmaken/aansluiten terwijl de reMarkable eruit is)

**Geverifieerd 2026-09-16** met een USB-unbind/bind van `1-2` (gelijk aan uit- en inpluggen):
interface verdween, kwam terug, en NetworkManager bracht hem **binnen 15 seconden uit zichzelf**
omhoog op `remarkable-usb` met 10.11.99.15/27. `eth0` behield gedurende de hele cyclus
`ethernet-eth1` en zijn adres, en `wlp2s0` bleef op `TorreiroNet`. Het profiel is MAC-gebonden en
kan de andere interfaces dus niet matchen.

*Opgeruimd onderweg:* het handmatige `ip addr add` uit de onderzoeksfase liet NetworkManager het
device als `connected (externally)` beschouwen, waardoor het eigen profiel niet activeerde. Eén
`nmcli device disconnect` + `nmcli device set … autoconnect yes` + `nmcli connection up
remarkable-usb` (bij naam, dus geen kapingsrisico) heeft dat rechtgezet.

## 3. Bereikbaarheidsprobe

- [x] 3.1 Probe implementeren die stil exit 0 geeft als `10.11.99.1` niet reageert
- [x] 3.2 Verifiëren met losgekoppelde kabel: `systemctl --user start remarkable-sync.service` eindigt exit 0 en de journal bevat geen foutregels

## 4. Backup-stap (SSH)

- [x] 4.1 Spiegelen van `/home/root/.local/share/remarkable/xochitl` naar `<targetDir>/backup/xochitl/`, zonder ongewijzigde bestanden aan te raken
- [x] 4.2 Verifiëren: eerste run levert 38 bestanden (~992 KB bij het huidige archief); tweede run wijzigt geen enkele mtime
- [x] 4.3 Verifiëren dat `backup.enable = false` geen SSH-verbinding opzet

**Geverifieerd 2026-09-16.** 3.2: de timer-run van 08:54:06 trof een onbereikbaar apparaat en
eindigde met exit 0 en één uitlegregel, zonder foutregels. 4.2: eerste run leverde **26 bestanden**
(de "38" in de taakomschrijving was het aantal tar-entries inclusief mappen) plus 3 PDF's, samen
2,5 MB; de tweede run raakte **geen enkel bestand** aan (mtime + grootte identiek). 4.3: met
`backup.enable = false` bevat het gegenereerde script 0 aanroepen van ssh, tar en rsync en
ontbreekt de backup-sectie volledig -- alleen de export blijft over.

## 5. Export-stap (webinterface)

- [x] 5.1 Listing ophalen via `GET /documents/` en parsen (`ID`, `VisibleName`, `Parent`, `Type`, `fileType`, `ModifiedClient`)
- [x] 5.2 Mappenboom reconstrueren uit `Parent`; items met `Type == "CollectionType"` overslaan als download
- [x] 5.3 Naamsanering: `/` en NUL vervangen, lege naam → UUID, leidende `.` vermijden, botsingen oplossen met een UUID-voorvoegsel zonder bestaande paden te wijzigen
- [x] 5.4 Downloaden via `GET /download/<ID>/placeholder`, **sequentieel**, `--max-time` minimaal 180 s, nooit afbreken
- [x] 5.5 Schrijven naar `<targetDir>/documenten/<pad>/<naam>.pdf`, atomisch (tijdelijk bestand + rename) zodat een afgebroken run geen halve PDF achterlaat
- [x] 5.6 Lokale PDF's verwijderen die niet meer in de listing voorkomen
- [x] 5.7 Verifiëren: alle documenten hebben `%PDF-` als header en `%%EOF` als slot; een beschreven document is merkbaar groter dan het origineel op het apparaat (gemeten referentie: 74.536 → 337.055 bytes)

## 6. Incrementeel exporteren

- [x] 6.1 State-bestand `~/.local/state/remarkable-sync/exported.json` (`ID → ModifiedClient`) schrijven en lezen
- [x] 6.2 Alleen downloaden bij een afwijkende `ModifiedClient`
- [x] 6.3 Verifiëren: tweede run zonder wijzigingen doet nul downloads en wijzigt nul PDF's
- [x] 6.4 Verifiëren: één notitie op het apparaat bijwerken → uitsluitend die PDF wordt vernieuwd
- [x] 6.5 Verifiëren: state-bestand weggooien → volledige her-export, daarna weer rust

**Geverifieerd 2026-09-16** door `export.py` los te draaien tegen het apparaat (scratchpad, niet
in `~/Nextcloud`): run 1 → 3 gedownload; run 2 → 0 gedownload, 3 ongewijzigd en **geen enkele
mtime gewijzigd**; PDF's alle drie `%PDF-…` + `%%EOF`, met 'Learn the basics' 74.536 → 337.055
bytes (de inkt zit erin). Prune verwijderde een neergezette wees-PDF én de lege map eromheen.
State weggooien gaf een volledige her-export, daarna weer rust.

*Kanttekening bij 6.4:* de selectieve her-download is aangetoond door in het state-bestand één
`ModifiedClient` te vervalsen — exact het codepad dat een echte bewerking op het apparaat
aanroept — waarna precies één PDF vernieuwd werd en de andere twee onaangeroerd bleven. Een
bewerking op de tablet zelf is niet apart uitgevoerd.

## 7. Timer en integratie

- [x] 7.1 `systemd.user.timer` met `OnActiveSec` + `OnUnitActiveSec = interval`
- [x] 7.2 `home-manager switch` uitvoeren en verifiëren dat timer en service bestaan
- [x] 7.3 Verifiëren dat `services.nextcloud-sync` de nieuwe map meeneemt: bestanden verschijnen op `nxc.toorren.net` onder `reMarkable/`
- [x] 7.4 Regressietest: de bestaande `nextcloud-sync-docs`-timer draait nog steeds en uploadt niet plotseling het hele archief opnieuw

**Opgelost 2026-09-16 — het was een bestaand defect, los van deze change.**
`nextcloud-sync-docs` faalde sinds **9 september**: 419 mislukte runs in zeven dagen, nul
geslaagde. De unit draait met `--silent`, dus er stond niets in de journal. Diagnose: server
gezond (`status.php` → 200, Nextcloud 34.0.3), maar WebDAV gaf **HTTP 429** — brute-force-
throttling (25.000 ms vertraging op het publieke IP), getriggerd door een week lang elke tien
minuten opnieuw proberen. Oorzaak daaronder: in `~/.config/nextcloud-sync/credentials` stond een
**12-tekens accountwachtwoord** in plaats van een app-password.

Terzijde gevonden: de brute-force-allowlist op de server bevatte `82.172.167.171/32` en `/24`
("technative HQ"), terwijl het gedetecteerde IP `82.172.137.171` is — derde octet 137 vs 167, dus
die regels dekten niets. Niet aangepast: allowlisten is de verkeerde oplossing voor een verkeerd
wachtwoord.

Hersteld met een nieuw app-password (29 tekens, `xxxxx-xxxxx-…`; oude credentials bewaard als
`credentials.bak-20260916-141434`). Daarna: WebDAV → **HTTP 207**, eerste sync geslaagd in 2 min
4 s, tweede in **3 seconden** (dus incrementeel, geen volledige herupload — 7.4). Op de server
staan nu `reMarkable/documenten/` met de drie PDF's in exact de juiste groottes en
`reMarkable/backup/xochitl/` met **26 bestanden**, gelijk aan lokaal (7.3).

## 8. Documentatie

- [x] 8.1 `docs/remarkable.md` schrijven: aansluiten, wachtwoord ophalen (Instellingen → Help → Over), de twee routes, de gemeten valkuilen (standby gooit de gadget weg; afgebroken download legt de webserver om tot xochitl herstart; `error -71` = kabel), en de herstelstap `systemctl restart xochitl`
- [x] 8.2 Verwijzing naar `docs/remarkable.md` toevoegen aan de contextbestanden-lijst boven in `CLAUDE.md`
- [x] 8.3 `CHANGELOG.md` bijwerken onder `## NEXT VERSION`

## 9. Bewust niet in deze change

- [x] 9.1 Vastleggen in de README dat udev-triggering (`idVendor=04b3, idProduct=4010`), documenten *naar* het apparaat schrijven, `rmfakecloud` en een eigen `.rm`-renderer bewust buiten scope vallen — elk een eigen change waard
