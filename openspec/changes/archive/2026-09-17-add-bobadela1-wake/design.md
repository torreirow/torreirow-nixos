# Design — add-bobadela1-wake

## Context

- **bobadela1**: non-NixOS testserver (Linux Mint), Nextcloud AIO op JuiceFS/S3. MAC `b8:ac:6f:c7:20:c6`,
  IP `192.168.2.67`. Gaat elke avond 23:00 uit (`nightly-shutdown`, koude start bewust). Nextcloud AIO
  luistert intern op `192.168.2.67:11000` (nxc.toorren.net termineert TLS op malandro en proxyt daarheen).
- **malandro**: altijd-aan NixOS-host op `192.168.2.52`, op dezelfde LAN. Draait al de signal-cli REST API
  (`127.0.0.1:8088`) en het `rustic-notify@`-patroon voor Signal-meldingen.
- **Bestaand script** `/home/wtoorren/bin/wake-bobadela1`: stuurt magic packets (poort 7 & 9 naar
  `192.168.2.255`), pollt `ping` en re-burst bij `--wait`. Werkt, maar los bestand + geen automatisering.

Geverifieerd tijdens exploratie: `GET http://192.168.2.67:11000/status.php` → `200` in ~0,13 s met
`{"installed":true,"maintenance":false,"needsDbUpgrade":false,...}`. Geen auth nodig.

## Goals / Non-goals

**Goals**
- Elke ochtend 09:00 automatisch bobadela1 wekken en pas stoppen als Nextcloud écht gezond is.
- Robuust doorzetten (30 min, burst elke 5 min) tegen gemiste packets / trage koude boot.
- Bij falen een **onderscheidende** Signal-melding (host-down vs Nextcloud-down).
- Eén bron voor de wake-logica, bruikbaar door de service én handmatig via `~/bin`.

**Non-goals**
- Geen continue health-monitoring van bobadela1 gedurende de dag (alleen de ochtend-wake).
- Geen wijziging aan het `nightly-shutdown` (23:00) op bobadela1.
- Geen RTC/BIOS-wake configureren (WoL vanaf malandro is de gekozen route).
- Geen generieke refactor van `rustic-notify@` (mag later; hier niet vereist).

## Belangrijke beslissingen

### 1. Trigger: systemd-timer 09:00, dagelijks, Persistent=true
`OnCalendar=*-*-* 09:00:00`, `Persistent=true`. malandro is altijd-aan, dus Persistent is zelden relevant;
staat een gemiste 09:00 (reboot) toe om alsnog ingehaald te worden — onschadelijk, want de service is
idempotent (doet niets als bobadela1 al gezond is).

### 2. Retry-lus zit in het script, niet in systemd
Eén `oneshot` die 30 min intern doorloopt is eenvoudiger dan systemd `Restart=`/`StartLimit`-tuning en
houdt de re-burst-cadans op één plek. Parameters: `--wait 1800` (venster), `--burst 300` (WoL elke 5 min →
6 bursts), ping-poll tussendoor (~10 s). `TimeoutStartSec` ruim boven 1800 (bijv. 2100).

### 3. Succes = Nextcloud gezond, met twee faal-modi
```
start ─▶ ping .67 al op? ─ja─▶ Nextcloud-fase
   │ nee
   ▼
 WoL-burst ─▶ POLL (max 30 min):
    • ping elke ~10s   • re-burst elke 5 min
    ├─ ping OK ─▶ NEXTCLOUD-FASE: poll status.php tot gezond OF venster op
    │              ├─ gezond ─▶ exit 0 (stil)
    │              └─ venster op, ping OK, NC niet ─▶ FAAL B → Signal
    └─ 30 min geen ping ─▶ FAAL A → Signal
```
Gezond = HTTP 200 op `http://192.168.2.67:11000/status.php` én JSON `installed==true` én
`maintenance==false`. De Nextcloud-fase deelt hetzelfde 30-min-venster (koude boot + container-start kost
tijd; "Waiting for Nextcloud to start" is normaal na een cold boot).

### 4. Wake-logica als gedeelde nix-derivation
De logica komt in een **derivation** (`pkgs.writers.writePython3Bin "wake-bobadela1"`), in een los bestand
zodat twee consumenten dezelfde bron delen:
- **Root system-service (malandro)** gebruikt de **store-path** (`${wake}/bin/wake-bobadela1 …`). Een
  root-service mag níet van `/home` (home-manager/NFS) afhangen.
- **home-manager** legt dezelfde derivation neer als `~/bin/wake-bobadela1`-symlink voor handmatig gebruik.

Eén binary, twee modi:
- service: `wake-bobadela1 --wait 1800 --burst 300 --check-nextcloud --notify`
- handmatig: `wake-bobadela1` (snel, geen notify) of met eigen flags.

### 5. Signal-notificatie in het script (best-effort)
Er bestaat nog geen generieke Signal-notifier; de enige is `rustic-notify@` (tekst hardcoded
"Backup-fout"). Omdat we twee verschillende teksten nodig hebben, stuurt het script zelf de melding via een
kleine helper met dezelfde constanten als `rustic-backup.nix`:
`api=http://127.0.0.1:8088/v2/send`, afzender `+31612652352`, ontvanger `+31636201589`. Best-effort
(`--max-time` + faal-tolerant), zodat een falende Signal-API de service-exitcode niet verandert. De service
krijgt daarnaast een `OnFailure=` naar een minimale notify als vangnet voor onverwachte crashes vóór het
script zelf kon melden.

## Alternatieven overwogen

| Alternatief | Waarom niet |
|----------------------------------|-----------------------------------------------------------|
| RTC/BIOS wake-alarm op bobadela1 | Niet-NixOS host, fragieler te beheren; WoL vanaf de altijd-aan malandro is centraal en versiebeheerd |
| systemd `Restart=on-failure` i.p.v. interne lus | Cadans + re-burst verspreid over unit-config; interne lus is 1 plek en al aanwezig |
| Alleen ping als succes | Vangt een host die boot maar waar Nextcloud niet opkomt niet; user wil expliciet de NC-check |
| `rustic-notify@` hergebruiken | Tekst is backup-specifiek; twee wake-teksten nodig → in-script send is schoner |

## Risico's / aandachtspunten
- **NFS/home-timing:** de root-service mag niet op `~/bin` leunen → store-path gebruiken (beslissing 4).
- **Cold-boot duur:** Nextcloud-containers kunnen minuten nodig hebben; het 30-min-venster vangt dat.
- **status.php via http op :11000:** geverifieerd bereikbaar vanaf malandro zonder auth; als AIO ooit de
  interne poort wijzigt, moet de check-URL mee.
- **WoL-broadcast:** vereist dat malandro en bobadela1 in hetzelfde L2-broadcastdomein zitten (nu zo).
