# remarkable-sync

Haalt de documenten van een via USB aangesloten **reMarkable 2** op en zet ze in een map onder
`~/Nextcloud`, waar `services.nextcloud-sync` ze vanzelf meeneemt.

```
  reMarkable 2                       lobos                        nxc.toorren.net
  ┌────────────────┐                 ┌──────────────────────────┐
  │ 10.11.99.1     │  SSH  :22  ────►│ …/reMarkable/backup/     │──┐
  │ (USB cdc_ether)│                 │   ruwe xochitl-map       │  │  bestaande
  │                │  HTTP :80  ────►│ …/reMarkable/documenten/ │  ├─ nextcloud-sync
  └────────────────┘                 │   PDF's mét inkt         │──┘  (elke 10 min)
                                     └──────────────────────────┘
```

## Inschakelen

```nix
services.remarkable-sync = {
  enable = true;
  # targetDir = "~/Nextcloud/reMarkable";  # default
  # interval  = "2min";                    # default
  # backup.enable = true;                  # ruwe spiegel over SSH
  # export.enable = true;                  # PDF's via de webinterface
};
```

De module wordt geïmporteerd vanuit `flake.nix` (modulelijst van
`homeConfigurations."wtoorren@linuxdesktop"`), de configuratie staat in `home/linux-desktop.nix`.

## Twee dingen moet je zelf doen

### 1. Zet de USB-webinterface aan

Op het apparaat: **Instellingen → Opslag → USB-webinterface**. Staat die uit, dan is poort 80
dicht en doet de export-stap niets (de backup-stap werkt wél).

### 2. Leg een SSH-sleutel neer (alleen nodig voor `backup.enable`)

Het root-wachtwoord staat op het apparaat onder **Instellingen → Help → Over**, onderaan bij de
GPLv3-mededeling.

```bash
ssh-keygen -t ed25519 -f ~/.ssh-priv/remarkable -C remarkable -N ""
ssh-copy-id -i ~/.ssh-priv/remarkable.pub root@10.11.99.1
```

**Waarom een los bestand en geen agent:** op lobos is `rbw` de ssh-agent. Die serveert uitsluitend
sleutels uit de Bitwarden-kluis en `ssh-add` kan er niets aan toevoegen. De module verwijst daarom
met een expliciete `IdentityFile` naar `~/.ssh-priv/remarkable`, net zoals de AWS-sleutels daar
staan.

**Na een firmware-update** verandert het root-wachtwoord en kan `authorized_keys` verdwenen zijn.
Haal het nieuwe wachtwoord opnieuw op en draai `ssh-copy-id` nog eens.

## Handmatig draaien

```bash
systemctl --user start remarkable-sync.service
journalctl --user -u remarkable-sync -n 30
systemctl --user list-timers remarkable-sync.timer
```

Is het apparaat er niet, dan eindigt de service met exit 0 en één regel uitleg. Dat is bedoeld
gedrag: zie hieronder.

## Wat je moet weten voordat je gaat debuggen

**Het apparaat is er meestal niet.** Zodra de tablet in standby gaat, verdwijnt de complete
USB-gadget van lobos — interface weg, ping dood. "De kabel zit erin" betekent dus niet
"bereikbaar". Daarom breekt de sync stil af in plaats van te falen.

**Een afgebroken download legt de webserver om.** De webinterface is een kleine
QtWebApp-threadpool ín het `xochitl`-proces. Wordt een download halverwege afgekapt, dan blijft
één handler hangen en geeft daarna *elk* verzoek HTTP 408 — ook `/` en `/assets/` — tot xochitl
herstart. Vandaar dat downloads sequentieel gaan en met een ruime timeout. Zit je toch vast:

```bash
ssh root@10.11.99.1 'systemctl restart xochitl'
```

**`error -71` in `journalctl -k` betekent kabel.** Dat is `-EPROTO`, een fout op de elektrische
laag. Eén defecte kabel gaf hier 46 enumeraties en 6 van die fouten in een half uur, kapte
downloads af (en dus de webserver), en liet de tablet herstarten. Controleer met:

```bash
journalctl -k --since -10min | grep -cE "usb 1-2: new high-speed USB device"   # hoort 1 te zijn
journalctl -k --since -10min | grep -c "error -71"                            # hoort 0 te zijn
```

**NetworkManager brengt de interface niet vanzelf omhoog.** Daarvoor is een profiel nodig dat op
**MAC-adres** is vastgezet; dat staat declaratief in `hosts/lobos/`. Gebruik nooit een kaal
`nmcli device connect <interface>`: NetworkManager kiest dan een willekeurig passend wired-profiel
en kan er een van een andere interface afpakken.

## Wat er níét in zit

Elk van deze punten is een eigen change waard; ze vallen bewust buiten deze module.

| Buiten scope | Waarom |
|--------------------------------|------------------------------------------------------|
| udev-trigger op `04b3:4010` | zou instant syncen bij inpluggen, maar het starten van een user-unit vanuit udev (`SYSTEMD_USER_WANTS`) is hier nog onbewezen; een timer van 2 minuten kost niets |
| Documenten *naar* het apparaat | vereist schrijven in `xochitl` plus een herstart daarvan, of de upload-endpoint |
| `rmfakecloud` | bidirectioneel en draadloos, maar vereist het apparaat naar een eigen cloud omleiden |
| Eigen `.rm`-renderer (`rmscene`)| overbodig zolang de webinterface bestaat; `rmscene` 0.8.0 loopt bovendien achter op firmware 3.28 ("Some data has not been read") |
| RCU | doet dit alles al, maar is een betaalde Qt-GUI zonder headless modus |

De ruwe backup houdt de tweede optie trouwens open: die levert de `.rm`-bestanden lokaal, dus een
offline renderer kan er later op werken zonder dat het apparaat aangesloten hoeft te zijn.

**Niet in de backup:** `/home/root/.config/remarkable/xochitl.conf`. Dat bestand bevat het
`DeveloperPassword`, de `Passcode` en een cloud-token, en valt buiten
`~/.local/share/remarkable/xochitl`. Bewust zo houden — anders belanden die geheimen in Nextcloud.
