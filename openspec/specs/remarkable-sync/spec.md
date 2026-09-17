# remarkable-sync Specification

## Purpose
TBD - created by archiving change add-remarkable-nextcloud-sync. Update Purpose after archive.

## Requirements

### Requirement: Ruwe backup van het reMarkable-archief
Het systeem SHALL de volledige map `/home/root/.local/share/remarkable/xochitl` van het apparaat
over SSH spiegelen naar een lokale backup-map, zodat het archief exact herstelbaar blijft.

#### Scenario: Apparaat bereikbaar
- **WHEN** de sync draait en `10.11.99.1` bereikbaar is
- **THEN** staan alle `.metadata`, `.content`, `.pdf` en `.rm`-bestanden onder
  `~/Nextcloud/reMarkable/backup/xochitl/`

#### Scenario: Ongewijzigd archief
- **WHEN** de sync twee keer achter elkaar draait zonder dat er op het apparaat iets is gewijzigd
- **THEN** wijzigt geen enkel bestand in de backup-map (geen nieuwe mtimes)

#### Scenario: Backup uitgeschakeld
- **WHEN** `backup.enable = false` is
- **THEN** wordt er geen SSH-verbinding opgezet en blijft de backup-map ongemoeid

### Requirement: PDF-export van alle documenten
Het systeem SHALL elk document van het apparaat als PDF ophalen via de USB-webinterface, zodat de
notities elders leesbaar zijn inclusief de handgeschreven inkt.

#### Scenario: Document met aantekeningen
- **WHEN** een geïmporteerd PDF-document op het apparaat is beschreven
- **THEN** bevat de geëxporteerde PDF de gerenderde inkt en niet alleen het origineel

#### Scenario: Geldige PDF
- **WHEN** een document is geëxporteerd
- **THEN** begint het bestand met `%PDF-` en eindigt het met `%%EOF`

#### Scenario: Map-items
- **WHEN** een item in de listing `Type == "CollectionType"` heeft
- **THEN** wordt er voor dat item geen download geprobeerd

### Requirement: Mappenboom en veilige bestandsnamen
Het systeem SHALL de mappenstructuur van het apparaat reconstrueren uit de `Parent`-verwijzingen
en `VisibleName` omzetten naar een veilige padnaam.

#### Scenario: Genest document
- **WHEN** een document een `Parent` heeft die naar een map verwijst
- **THEN** staat de PDF in een gelijknamige submap onder `documenten/`

#### Scenario: Naam met een schuine streep
- **WHEN** een `VisibleName` een `/` bevat
- **THEN** wordt die vervangen en ontstaat er geen extra mapniveau

#### Scenario: Twee documenten met dezelfde naam in dezelfde map
- **WHEN** twee documenten in dezelfde map dezelfde `VisibleName` hebben
- **THEN** krijgt elk bestand een uniek pad, en wijzigt het pad van reeds bestaande documenten niet
  door de komst van een derde gelijknamig document

#### Scenario: Verwijderd document
- **WHEN** een document niet meer in `/documents/` voorkomt
- **THEN** wordt de bijbehorende lokale PDF verwijderd

### Requirement: Alleen gewijzigde documenten opnieuw exporteren
Het systeem SHALL per document de `ModifiedClient`-waarde uit de listing vergelijken met een
lokaal state-bestand en alleen bij een afwijking opnieuw downloaden, zodat de Nextcloud-sync niet
bij elke run het hele archief opnieuw uploadt.

#### Scenario: Niets gewijzigd
- **WHEN** de sync draait en geen enkel document is sinds de vorige run gewijzigd
- **THEN** wordt er geen enkele download uitgevoerd en wijzigt geen enkele PDF

#### Scenario: Eén document gewijzigd
- **WHEN** één document op het apparaat is bijgewerkt
- **THEN** wordt uitsluitend dat document opnieuw gedownload

#### Scenario: State-bestand ontbreekt
- **WHEN** het state-bestand niet bestaat of onleesbaar is
- **THEN** exporteert de sync alle documenten opnieuw en schrijft een nieuw state-bestand

### Requirement: Stil afbreken bij een afwezig apparaat
Het systeem SHALL de sync zonder foutmelding beëindigen wanneer het apparaat niet bereikbaar is,
omdat afwezigheid het normale geval is: de tablet slaapt, of de kabel zit er niet in.

#### Scenario: Apparaat slaapt of is losgekoppeld
- **WHEN** `10.11.99.1` niet bereikbaar is
- **THEN** eindigt de service met exit 0 en zonder foutregels in de journal

#### Scenario: Apparaat verdwijnt tijdens de run
- **WHEN** de verbinding halverwege wegvalt
- **THEN** eindigt de service zonder de reeds gedownloade bestanden of het state-bestand te
  beschadigen, en wordt de rest bij een volgende run opgehaald

### Requirement: Geen afgebroken verzoeken aan de webinterface
Het systeem SHALL elk HTTP-verzoek aan het apparaat sequentieel en met een ruime timeout
uitvoeren, omdat een afgekapt verzoek de webserver van xochitl onbruikbaar achterlaat tot het
apparaat herstart.

#### Scenario: Traag renderend document
- **WHEN** het apparaat langer dan een minuut doet over het renderen van een document
- **THEN** wacht de sync dat af en breekt het verzoek niet af

#### Scenario: Meerdere documenten
- **WHEN** er meerdere documenten geëxporteerd moeten worden
- **THEN** worden de downloads één voor één uitgevoerd, nooit parallel

### Requirement: Periodieke uitvoering via een user-timer
Het systeem SHALL de sync periodiek starten met een `systemd.user.timer`, zodat het aansluiten van
het apparaat binnen enkele minuten tot een sync leidt zonder handmatige actie.

#### Scenario: Timer actief na login
- **WHEN** de gebruiker is ingelogd
- **THEN** is `remarkable-sync.timer` actief en start hij de service periodiek

#### Scenario: Handmatig starten
- **WHEN** de gebruiker `systemctl --user start remarkable-sync.service` uitvoert
- **THEN** draait dezelfde sync onmiddellijk

### Requirement: Configureerbaar via home-manager
Het systeem SHALL de sync aanbieden als home-manager-module met losse schakelaars voor de backup-
en de export-stap, in dezelfde stijl als `services.nextcloud-sync`.

#### Scenario: Module uitgeschakeld
- **WHEN** `services.remarkable-sync.enable = false` is
- **THEN** bestaan de service en de timer niet

#### Scenario: Doelmap instelbaar
- **WHEN** een afwijkende doelmap is opgegeven
- **THEN** landen backup en export onder die map, en wordt een leidende `~/` geëxpandeerd

#### Scenario: Geen geheimen in de nix-store
- **WHEN** de module is gebouwd
- **THEN** bevat geen enkel bestand in de nix-store het root-wachtwoord of de private sleutel van
  het apparaat
