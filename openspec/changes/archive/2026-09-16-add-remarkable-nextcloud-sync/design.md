# Design — remarkable-sync

Alle onderstaande cijfers zijn op 2026-09-15 gemeten op het daadwerkelijke apparaat
(reMarkable 2, firmware 3.28.0.172, Codex Linux 5.8.203, kernel `5.4.70-v1.6.3-rm11x`, armv7l),
niet geschat.

## Context: wat het apparaat aanbiedt

```
  lobos                                        reMarkable 2  (04b3:4010)
  ┌───────────────────────────┐               ┌──────────────────────────────┐
  │ enp100s0f3u2c2            │  USB cdc_ether│ 10.11.99.1                   │
  │ 10.11.99.15/27  (DHCP)    │◄─────────────►│                              │
  └───────────────────────────┘               │ :22  dropbear 2025.88        │
                                              │ :80  xochitl HTTP (QtWebApp) │
                                              └──────────────────────────────┘
```

Op schijf is alles plat en UUID-genoemd; de mappenboom bestaat uitsluitend als `parent`-
verwijzingen in de JSON:

```
/home/root/.local/share/remarkable/xochitl/
├── <uuid>.metadata      {"visibleName":"…","parent":"<uuid>","type":"DocumentType"}
├── <uuid>.content       {"fileType":"notebook"|"pdf"|"epub", …}
├── <uuid>.pdf           origineel, alleen bij geïmporteerde documenten
└── <uuid>/<page>.rm     "reMarkable .lines file, version=6"
```

## Beslissing 1 — Twee routes, niet één

| | Ruwe backup (SSH) | PDF-export (webinterface) |
|---|---|---|
| Kanaal | dropbear `:22` | xochitl `:80` |
| Gemeten | 992 KB / 38 bestanden / **0,9 s** | 0,5-3 s per document |
| Levert | exact herstelbaar archief | leesbare PDF's mét inkt |
| Leesbaar elders | nee (UUID's, binair) | ja |
| Terugzetten na ramp | ja | nee |

Ze beantwoorden verschillende vragen en kosten samen bijna niets. Beide worden geïmplementeerd,
elk los uitschakelbaar. De backup is de verzekering; de export is het gemak.

Bijkomend voordeel van de backup: hij levert de ruwe `.rm`-bestanden lokaal op lobos. Mocht
reMarkable de webinterface ooit verwijderen, dan kan een offline renderer (`rmscene`) daarop
werken zonder dat het apparaat aangesloten hoeft te zijn. `rmscene` 0.8.0 leest deze v6-bestanden
(131 blocks, 58 `SceneLineItemBlock`), maar waarschuwt *"Some data has not been read"* — firmware
3.28 loopt voor op de parser. Daarom nu expliciet **niet** gebruiken.

## Beslissing 2 — Nooit een lopend verzoek afbreken

De webserver in xochitl is een kleine QtWebApp-threadpool binnen het `xochitl`-proces. Een
afgekapte download liet één `HttpConnectionHandler` hangen die daarna op **élk** verzoek
`read timeout occured` gaf en HTTP 408 retourneerde — ook op `/` en `/assets/` — en dat bleef
ruim twee uur zo, een USB-herplug incluis. Pas na een herstart van xochitl werkte alles weer.

Consequentie voor de implementatie:

- `curl` met een **ruime** `--max-time` (minimaal 180 s per document), nooit korter.
- Verzoeken strikt **sequentieel**, nooit parallel.
- Bij een fout: stoppen en het bij de volgende run opnieuw proberen — niet meteen opnieuw
  aanvallen.

Dit was aanvankelijk gediagnosticeerd als inherente broosheid van de webserver. Dat was fout: de
oorzaak was een defecte USB-kabel die de download halverwege afkapte (zie beslissing 6). De
maatregel blijft niettemin staan, want het faalgedrag is reëel en de kosten zijn nul.

## Beslissing 3 — Incrementeel exporteren op `ModifiedClient`

`nextcloudcmd` synct op mtime en etag. Als elke run alle PDF's opnieuw schrijft, ziet Nextcloud
elke 10 minuten een compleet gewijzigd archief en upload het alles opnieuw.

`/documents/` levert per document een `ModifiedClient` (ISO-8601, bv. `2026-09-15T20:27:51.23Z`).
Die wordt vergeleken met een lokaal state-bestand (`~/.local/state/remarkable-sync/exported.json`,
`ID → ModifiedClient`). Alleen bij een afwijking wordt opnieuw gedownload.

De backup-stap heeft dit niet nodig: die spiegelt de map en laat ongewijzigde bestanden met rust.

## Beslissing 4 — Mappenboom en bestandsnamen

`VisibleName` is vrije tekst van de gebruiker en komt rechtstreeks in een pad terecht. Nodig:

- `/` en NUL vervangen, lege namen vervangen door het UUID;
- leidende `.` vermijden;
- botsingen oplossen door het UUID-voorvoegsel (eerste 8 tekens) toe te voegen, **alleen** bij een
  daadwerkelijke botsing — anders wijzigen paden bij elke nieuwe gelijknamige notitie.

De boom wordt gereconstrueerd door `Parent` te volgen tot de lege string (= root). Mappen zijn
items met `Type == "CollectionType"`; die hebben geen download-endpoint.

Verwijderde documenten verdwijnen uit `/documents/`. De export verwijdert lokale PDF's die niet
meer in de listing staan, zodat de map een spiegel blijft — dat is bewust, en de reden dat de
map geen prullenbak is.

## Beslissing 5 — Uitvoering: timer, niet udev (voorlopig)

Een udev-regel op `idVendor=04b3, idProduct=4010` zou instant reageren op inpluggen. Dat is
aantrekkelijk maar introduceert een systeem-module náást de home-manager-module, en het starten
van een *user*-unit vanuit udev (`SYSTEMD_USER_WANTS`) is in deze repo nog nergens gebruikt en
dus onbewezen.

Daarom: **`systemd.user.timer`**, net als `nextcloud-sync`. Interval 2 minuten — de kosten zijn
één bereikbaarheidsprobe. De service beëindigt stil (exit 0) als het apparaat er niet is.

Let op: de interfacenaam `enp100s0f3u2c2` is padgebaseerd en verandert per USB-poort. Nergens op
vertrouwen; de probe gaat op `10.11.99.1`, niet op een interfacenaam.

udev blijft een mogelijke latere verbetering, als losse change.

## Beslissing 6 — Het apparaat is er meestal niet

Twee onafhankelijke oorzaken, beide gemeten:

1. **Standby.** Zodra de tablet in slaap valt, verdwijnt de complete USB-gadget van lobos —
   interface weg, ping dood. "Kabel zit erin" betekent niet "bereikbaar".
2. **Defecte kabel.** 46 enumeraties en 6× `error -71` (-EPROTO) in 30 minuten, terwijl geen enkel
   ander USB-apparaat in de machine ook maar één fout gaf. Het apparaat zelf is vrijgepleit:
   correcte gadget-respons bij elke enumeratie, accu 60-64% en ladend, `power/control=on` (dus
   geen autosuspend). Tijdens de tests herstartte de tablet.

Dit is de reden dat afwezigheid **normaal gedrag** is en niet als fout mag worden gerapporteerd.
Een service die elke 2 minuten faalt vervuilt de journal en traint je om meldingen te negeren.

De kabel is een hardware-voorwaarde, geen ontwerpprobleem. Maar hij moet vervangen zijn voordat
deze change zinvol te valideren is: korte operaties overleven het flapperen, langere niet.

## Beslissing 7 — Authenticatie

De backup-stap heeft SSH nodig. Op lobos is **rbw de ssh-agent** en `ssh-add` kan geen sleutels
toevoegen — de agent serveert uitsluitend sleutels uit de Bitwarden-kluis. Een reMarkable-sleutel
komt daarom als bestand in `~/.ssh-priv/` met een expliciete `IdentityFile` in een `Host`-blok,
zoals de AWS-sleutels daar ook staan.

Het root-wachtwoord van het apparaat staat in Instellingen → Help → Over en **verandert bij elke
firmware-update**. De publieke sleutel in `/home/root/.ssh/authorized_keys` overleeft updates niet
gegarandeerd; het herstellen daarvan hoort in de README, niet in de module.

Geen wachtwoord in de nix-store, geen wachtwoord in de unit — zelfde regel als bij
`nextcloud-sync`.

## Beslissing 8 — De interface komt niet vanzelf omhoog (en `nmcli device connect` is gevaarlijk)

NetworkManager laat `enp100s0f3u2c2` op `disconnected` staan terwijl de link er wél is:

```
GENERAL.STATE:              30 (disconnected)
GENERAL.REASON:             40 (Carrier/link changed)
WIRED-PROPERTIES.CARRIER:   on
```

Er wordt geen DHCP geprobeerd — de journal van NetworkManager bevat geen enkele poging. Zonder
ingrijpen is het apparaat dus onbereikbaar, ook al is alles fysiek in orde.

**Wat je NIET moet doen.** Een kaal `nmcli device connect <interface>` lijkt de oplossing, maar
NetworkManager kiest dan *elk* passend wired-profiel. Gemeten op 2026-09-16: het greep
`ethernet-eth1`, het profiel dat op dat moment in gebruik was door de ethernet-adapter van het
dock (`eth0`). Gevolg: `eth0` viel terug naar `disconnected` en verloor zijn adres, terwijl de
reMarkable-interface het profiel overnam. Hersteld met `nmcli device disconnect` gevolgd door
`nmcli device connect eth0`; het profielbestand zelf bleef ongemoeid (mtime onveranderd).

**Wat wel.** Een eigen NetworkManager-profiel dat op **MAC-adres** is vastgezet, niet op
interfacenaam:

```
802-3-ethernet.mac-address = 7a:17:67:41:44:36
connection.autoconnect     = true
ipv4.method                = auto          # de reMarkable draait zelf een DHCP-server
```

Twee redenen voor MAC en niet naam:

- De interfacenaam is padgebaseerd (`enp100s0f3u2c2` = USB-poort 1-2) en verandert zodra het
  apparaat in een andere poort gaat.
- Een MAC-gebonden profiel kan per definitie geen andere interface kapen — precies de fout
  hierboven wordt er structureel mee uitgesloten.

Het MAC-adres van de gadget is stabiel: over 65 enumeraties in 20 uur kwam uitsluitend
`7a:17:67:41:44:36` voorbij.

**Consequentie voor de vorm van de change:** dit profiel is systeemniveau, niet home-manager. Het
hoort declaratief in `hosts/lobos/` (`networking.networkmanager.ensureProfiles`), náást de
home-manager-module met de sync zelf. De sync-service blijft daardoor een gewone user-service
zonder root-rechten: hij hoeft geen adressen te configureren, alleen te constateren dat
`10.11.99.1` antwoordt.

Een alternatief zonder NetworkManager — de service zelf `ip addr add 10.11.99.15/27` laten doen —
is verworpen: dat vereist `CAP_NET_ADMIN` en dus een sudo-regel of een systeem-service, voor iets
waar NetworkManager al voor bestaat. (Voor de validatietests is die route wél gebruikt, puur
runtime en zonder profiel, om het systeem niet aan te raken.)

## Afgewogen en verworpen

- **RCU** (`pkgs.rcu`, AGPL-3.0+): doet dit alles al en praat via SSH (paramiko), dus het omzeilt
  de webinterface volledig. Maar het is `requireFile` (je koopt de tarball zelf bij davisr.me) en
  het is een Qt6-**GUI** zonder headless modus. Uitstekend handgereedschap, geen antwoord op
  "het gebeurt vanzelf". Door de gebruiker afgewezen.
- **`rmfakecloud`** op malandro: bidirectioneel, draadloos, met de native sync-logica van het
  apparaat. Architectonisch aantrekkelijk, maar vereist het omleiden van het apparaat naar een
  eigen cloud en offert de officiële cloud op. Veel groter dan de vraag.
- **Eigen renderer** (`rmscene`/`rmrl`): overbodig zolang de webinterface bestaat, en 0.8.0 loopt
  achter op firmware 3.28 (zie beslissing 1).
- **Documenten naar het apparaat schrijven** (inbox): vereist schrijven in `xochitl` plus een
  herstart van xochitl, of de upload-endpoint van de webinterface. Niet gevraagd, eigen change.
