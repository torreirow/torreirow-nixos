## Why

Notities en geannoteerde documenten van de **reMarkable 2** staan nu uitsluitend op het apparaat
zelf. Er is geen backup en ze zijn nergens anders leesbaar. De officiële reMarkable-cloud is geen
optie (privacy/eigen infrastructuur), en het apparaat slaat alles op in een plat UUID-formaat met
binaire `.rm`-bestanden (formaat **v6**, firmware 3.28.0.172) dat zonder renderer onleesbaar is.

Op **lobos** staat de andere helft van de oplossing al klaar: `services.nextcloud-sync` synct
`~/Nextcloud` elke 10 minuten naar `nxc.toorren.net`. Wat ontbreekt is de stap van apparaat naar
die map.

Beide benodigde routes zijn op 2026-09-15 gemeten op de daadwerkelijke hardware:

- **Ruwe backup over SSH** — `tar -cz` van `/home/root/.local/share/remarkable/xochitl`:
  992 KB, 38 bestanden, **0,9 seconde**. Alleen dropbear nodig.
- **PDF-export via de USB-webinterface** — `GET /documents/` geeft JSON met
  `ID`/`VisibleName`/`Parent`/`fileType`; `GET /download/<ID>/placeholder` geeft een geldige PDF
  **met de inkt erin gerenderd** door de officiële renderer op het apparaat zelf (74 KB origineel
  → 337 KB export), in 0,5-3 seconden. Geen eigen renderer nodig.

Daarmee is er geen reden meer om `rmscene`, `rmrl` of RCU in te zetten: het apparaat rendert beter
dan wij dat kunnen, en gratis.

## What Changes

- **Nieuwe home-manager-module `home/module/remarkable-sync/`** in dezelfde stijl als de bestaande
  `home/module/nextcloud-sync/`: een oneshot `systemd.user.service` met een `systemd.user.timer`.
- **Twee onafhankelijke stappen per run**, elk los uitschakelbaar:
  1. `backup` — ruwe spiegel van de `xochitl`-map over SSH naar `~/Nextcloud/reMarkable/backup/`.
  2. `export` — PDF per document via de webinterface naar `~/Nextcloud/reMarkable/documenten/`,
     met de mappenboom gereconstrueerd uit de `Parent`-verwijzingen.
- **Incrementeel exporteren** op basis van `ModifiedClient` uit `/documents/`, bijgehouden in een
  lokaal state-bestand. Zonder dit herschrijft elke run alle PDF's en upload `nextcloudcmd` je hele
  archief opnieuw, elke 10 minuten.
- **Stil afbreken wanneer het apparaat er niet is** (slaapt, kabel eruit): exit 0, geen
  foutmeldingen in de journal.
- **Nooit een lopend verzoek afbreken** — ruime timeouts. Een afgekapte download laat xochitl's
  HTTP-handler hangen tot het apparaat herstart.
- **Buiten scope:** documenten *naar* het apparaat schrijven (inbox), `rmfakecloud`, RCU, een eigen
  `.rm`-renderer, en synchronisatie over WiFi.

## Capabilities

### New Capabilities

- `remarkable-sync`: Haalt periodiek de documenten van een via USB aangesloten reMarkable op — als
  ruwe backup én als leesbare PDF's — en zet ze in een map die door de bestaande Nextcloud-sync
  wordt meegenomen.

### Modified Capabilities

<!-- Geen bestaande capability raakt het reMarkable-apparaat; nextcloud-sync blijft ongewijzigd. -->

## Impact

- **Host:** alleen `lobos`. De sync zelf via home-manager (`home/linux-desktop.nix`); daarnaast
  één systeemniveau-toevoeging in `hosts/lobos/`: een NetworkManager-profiel dat op **MAC**
  (`7a:17:67:41:44:36`) is vastgezet, omdat NM de gadget-interface anders op `disconnected` laat
  staan en een kaal `nmcli device connect` het profiel van een andere interface kaapt (design,
  beslissing 8).
- **Nieuw:** `home/module/remarkable-sync/` (module + README), en de map
  `~/Nextcloud/reMarkable/` met `backup/` en `documenten/`.
- **Ongewijzigd:** `services.nextcloud-sync` pikt de nieuwe map vanzelf op; geen aanpassing nodig.
- **Voorwaarde (hardware) — voldaan op 2026-09-16.** De oorspronkelijke USB-kabel was defect
  (46 enumeraties en 6× `error -71` in 30 minuten; het apparaat herstartte tijdens de tests). Met
  een nieuwe kabel: **1 enumeratie, 0 disconnects, 0× `error -71`** over 25 minuten, en de
  volledige keten is end-to-end gevalideerd — backup 992.679 bytes in 0,9 s, listing http 200,
  drie downloads http 200 met geldige PDF's (`%PDF-…` + `%%EOF`), en de webinterface antwoordt
  ná afloop nog steeds met 200. Daarmee is ook bevestigd dat de eerdere 408's van de kabel kwamen
  en niet van xochitl.
- **Let op:** `~/Nextcloud` synct twee kanten op. Verwijder je een geëxporteerde PDF elders, dan
  zet de volgende run hem terug. Dat is bedoeld gedrag — de map is een spiegel van het apparaat —
  maar het is geen prullenbak.
