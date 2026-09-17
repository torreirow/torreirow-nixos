# reMarkable 2 via USB — backup en PDF-export naar Nextcloud (lobos)

**Laatst bijgewerkt:** 2026-09-16

## Kernpunt

De reMarkable hangt via USB aan lobos en presenteert zich als een **CDC-ethernet gadget**: het is
geen USB-stick, maar een netwerkapparaat op **10.11.99.1**. Daarop draaien twee diensten:

| Poort | Dienst | Gebruikt voor |
|-------|---------------------------|--------------------------------------------|
| 22 | dropbear (SSH, user `root`) | ruwe backup van de `xochitl`-map |
| 80 | webinterface in `xochitl` | PDF-export, door het apparaat zelf gerenderd |

Beide worden gebruikt door `services.remarkable-sync` (home-manager, elke 2 minuten). Alles landt
in `~/Nextcloud/reMarkable/`, waar de bestaande `services.nextcloud-sync` het meeneemt.

```
~/Nextcloud/reMarkable/
├── backup/xochitl/     ruwe spiegel — exact herstelbaar, onleesbaar (UUID's + binaire .rm)
└── documenten/         PDF's met de inkt erin — leesbaar op elk apparaat
```

## Waar staat dit geconfigureerd

- `home/module/remarkable-sync/` — de module (`default.nix`, `export.py`) + README met de
  handmatige stappen (SSH-sleutel, webinterface aanzetten).
- `flake.nix` — import in de modulelijst van `homeConfigurations."wtoorren@linuxdesktop"`.
- `home/linux-desktop.nix` — `services.remarkable-sync.enable = true;`.
- `hosts/lobos/remarkable-network.nix` — het NetworkManager-profiel.

## Aansluiten

1. Kabel in een **datapoort** (zie hieronder — een laadkabel is de klassieke valkuil).
2. Op het apparaat: **Instellingen → Opslag → USB-webinterface** aanzetten.
3. Eenmalig een SSH-sleutel neerleggen. Het root-wachtwoord staat op het apparaat onder
   **Instellingen → Help → Over**, onderaan bij de GPLv3-mededeling:

```bash
ssh-keygen -t ed25519 -f ~/.ssh-priv/remarkable -C remarkable -N ""
ssh-copy-id -i ~/.ssh-priv/remarkable.pub root@10.11.99.1
```

Na een firmware-update verandert het root-wachtwoord; herhaal dan stap 3.

## Handmatig draaien en controleren

```bash
systemctl --user start remarkable-sync.service
journalctl --user -u remarkable-sync -n 30
systemctl --user list-timers remarkable-sync.timer

# de webinterface rechtstreeks bevragen
curl -s http://10.11.99.1/documents/ | head -c 400
curl -s -o /tmp/test.pdf -w '%{http_code}\n' \
  http://10.11.99.1/download/<UUID>/placeholder
```

## Drie valkuilen die je uren kunnen kosten

### 1. Een slapende reMarkable is een afwezige reMarkable

Zodra de tablet in standby gaat, **verdwijnt de complete USB-gadget** van lobos: netwerkinterface
weg, ping dood, SSH-timeout. "De kabel zit erin" betekent dus niet "bereikbaar". De standby-
vertraging staat níét in `xochitl.conf` — het is een instelling in de UI van het apparaat.

De sync breekt hier bewust **stil** op af (exit 0, één regel uitleg). Een service die elke twee
minuten faalt, traint je om meldingen te negeren.

### 2. `error -71` betekent kabel, niet software

```bash
journalctl -k --since -10min | grep -cE "usb 1-2: new high-speed USB device"   # hoort 1 te zijn
journalctl -k --since -10min | grep -c "error -71"                            # hoort 0 te zijn
```

`error -71` is `-EPROTO`: een fout op de elektrische laag, vrijwel altijd de kabel of een vuile
connector. Een defecte kabel gaf hier **46 enumeraties en 6 van die fouten in een half uur**,
terwijl geen enkel ander USB-apparaat in de machine ook maar één fout gaf. Gevolgen: afgekapte
downloads, een omgevallen webserver (zie 3) en zelfs een herstart van de tablet.

Het apparaat zelf is daarbij onschuldig: het antwoordt bij elke enumeratie correct
(`configfs-gadget: high-speed config #2`), de accu laadt gewoon door.

### 3. Een afgebroken download legt de webserver om

De webinterface is een kleine **QtWebApp-threadpool ín het `xochitl`-proces**. Wordt een download
halverwege afgekapt, dan blijft één handler hangen en geeft daarna *élk* verzoek HTTP 408 — ook
`/` en `/assets/` — tot xochitl herstart. Hier bleef dat ruim twee uur zo, een USB-herplug incluis.

In het journal van het apparaat zie je dan onafgebroken:

```
xochitl[333]: HttpConnectionHandler (0x4b73778): read timeout occured
```

Herstel:

```bash
ssh root@10.11.99.1 'systemctl restart xochitl'
```

Daarom doet de module downloads **sequentieel** en met een ruime timeout (300 s), en breekt hij
nooit een lopend verzoek af.

## NetworkManager brengt de interface niet vanzelf omhoog

Zonder profiel blijft de interface op `disconnected` staan terwijl de link er wél is:

```
GENERAL.STATE:              30 (disconnected)
GENERAL.REASON:             40 (Carrier/link changed)
WIRED-PROPERTIES.CARRIER:   on
```

Daarvoor is `hosts/lobos/remarkable-network.nix`: een profiel dat op **MAC-adres**
(`7A:17:67:41:44:36`) is vastgezet, niet op interfacenaam. Twee redenen:

- de interfacenaam is padgebaseerd (`enp100s0f3u2c2` = USB-poort 1-2) en verandert per poort;
- een MAC-gebonden profiel kan per definitie geen andere interface kapen.

⚠️ **Gebruik nooit een kaal `nmcli device connect <interface>`.** NetworkManager kiest dan een
willekeurig passend wired-profiel. Op 2026-09-16 greep het `ethernet-eth1` — het profiel dat in
gebruik was door de ethernet-adapter van het dock — waarna `eth0` zijn verbinding verloor.
Herstel destijds: `nmcli device disconnect <interface>` gevolgd door `nmcli device connect eth0`.

## Hoe het apparaat zijn data opslaat

Alles staat plat en UUID-genoemd in `/home/root/.local/share/remarkable/xochitl/`; de mappenboom
bestaat uitsluitend als `parent`-verwijzingen in de JSON:

```
<uuid>.metadata     {"visibleName":"…","parent":"<uuid>","type":"DocumentType"}
<uuid>.content      {"fileType":"notebook"|"pdf"|"epub", …}
<uuid>.pdf          het origineel, alleen bij geïmporteerde documenten
<uuid>/<page>.rm    "reMarkable .lines file, version=6"
```

Daarom is de ruwe backup onleesbaar voor mensen en heb je de PDF-export ernaast nodig. De export
laat het apparaat zelf renderen — dat is de officiële renderer, inclusief pendruk en templates.
Meetpunt: een beschreven document van 74.536 bytes komt er als **337.055 bytes** uit.

**Niet in de backup:** `/home/root/.config/remarkable/xochitl.conf` bevat het `DeveloperPassword`,
de `Passcode` en een cloud-token. Dat bestand valt buiten de `xochitl`-datamap en blijft daar
bewust buiten — anders belanden die geheimen in Nextcloud.

## Zie ook

- `home/module/remarkable-sync/README.md` — handmatige stappen en wat bewust buiten scope valt
- `home/module/nextcloud-sync/` — de sync die de map naar `nxc.toorren.net` brengt
- `docs/usb-dongles.md` — het andere USB-verhaal op deze configuratie (stabiele device-paden)
