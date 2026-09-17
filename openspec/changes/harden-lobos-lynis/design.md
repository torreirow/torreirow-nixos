## Context

Alle cijfers hieronder komen uit de lynis-run van 2026-09-14 op lobos (`/var/log/lynis.log`,
`/var/log/lynis-report.dat`) en uit de `AddHP`-aanroepen in de lynis-broncode zelf
(`share/lynis/include/tests_*`). Er is niets geschat: per test is opgezocht hoeveel punten een
geslaagde en een gefaalde uitkomst toekennen.

Uitgangspunt: **158 / 244 = 64,75 → `hardening_index = 64`**.

Belangrijk kader voor élke beslissing hieronder: lobos is een **dagelijks gebruikte laptop** met
Docker, WiFi-resume-hacks en een GNOME/Hyprland-desktop. Het lynis-scanprofiel gaat uit van een
server. Een hogere index is daarom geen doel op zich — het is een meetlat die op punten de verkeerde
machine beschrijft.

## Goals / Non-Goals

**Goals**

- Meetfouten wegnemen waar lynis iets niet ziet dat er wél is (firewall).
- Bestaande maar inactieve configuratie oplossen (`modules/hardening.nix`).
- Een intern tegenstrijdige toestand oplossen (auditd draait, doet niets).
- De sysctl-sleutels rechttrekken die op dit type machine gedragsneutraal zijn.

**Non-Goals**

- Maximaliseren van de index. Vijf van de zeventien sysctl-afwijkingen worden bewust gelaten.
- Nieuwe daemons of nieuw beleid introduceren (AIDE, USBGuard, wachtwoordveroudering).
- De sudo/sshd-postuur van lobos herzien — dat is een losse, zwaardere beslissing.

## Decisions

### Beslissing 1: firewall-detectie repareren via `nft` in PATH, niet via `networking.nftables.enable`

De detectieketen breekt op twee plekken:

```
FIRE-4502  grept /proc/config.gz → CONFIG_IP_NF_IPTABLES
           NixOS bouwt dit als module, niet builtin
           → "no iptables found in Linux kernel config file"
           → FIRE-4508 / 4512 / 4513 SKIPPED

FIRE-4536  vereist NFTBINARY (`nft` in PATH) als preconditie
           $ command -v nft → MISSING
           → SKIPPED

FIRE-4590  FIREWALL_ACTIVE is nog 0 → AddHP 0 5
```

De test in `FIRE-4536` is letterlijk `lsmod | grep "^nf*_tables"` — dat zou op lobos slagen
(`nf_tables` is geladen, `iptables` is de `nf_tables`-variant). Hij wordt alleen nooit uitgevoerd
omdat het meetinstrument ontbreekt.

**Gekozen:** `nftables` aan de systeempakketten toevoegen.
**Overwogen en verworpen:** `networking.nftables.enable = true`. Dat zou de firewall-backend
daadwerkelijk omzetten in plaats van alleen zichtbaar maken, met gevolgen voor Docker's
iptables-regels en voor de bestaande `allowedTCPPorts`/`allowedUDPPorts`. Onnodig risico voor een
detectieprobleem.

### Beslissing 2: auditd een minimale ruleset geven in plaats van uitzetten

`ACCT-9630` kent `AddHP 0 2` toe bij een lege ruleset. Beide uitwegen — regels definiëren óf de
daemon uitzetten — leveren dezelfde 2 punten op.

**Gekozen:** een minimale ruleset definiëren via `security.audit.rules`.

Reden: `security.auditd.enable = true` staat er bewust, en de unit `audit-rules-nixos` is al actief.
De huidige toestand is geen keuze maar een half afgemaakte configuratie. Regels toevoegen maakt de
oorspronkelijke bedoeling waar; uitzetten gooit een capaciteit weg om een audit-score te halen.

**Open punt voor de uitvoering:** hou de ruleset klein en gericht (bijvoorbeeld wijzigingen aan
`/etc/passwd`, `/etc/shadow`, `/etc/sudoers` en het laden van kernelmodules). Een uitgebreide
ruleset op een desktop genereert veel ruis en kost merkbaar I/O, wat op deze thermisch krappe APU
(zie change `throttle-nix-builds`) niet gratis is. Als bij verificatie blijkt dat de logruis of de
belasting niet in verhouding staat, is `security.auditd.enable = false` het eerlijker alternatief —
dezelfde punten, minder schijnzekerheid.

### Beslissing 3: de sysctl-subset — 12 wel, 5 niet

Alle 17 afwijkingen uit `KRNL-6000`, elk 1 punt, met de huidige waarde op lobos:

| Sleutel                                  | Nu | Profiel | Oordeel |
|------------------------------------------|----|---------|---------|
| `fs.protected_fifos`                      | 1  | 2       | veilig  |
| `fs.protected_regular`                    | 1  | 2       | veilig  |
| `fs.suid_dumpable`                        | 2  | 0       | veilig  |
| `dev.tty.ldisc_autoload`                  | 1  | 0       | veilig  |
| `kernel.kptr_restrict`                    | 1  | 2       | veilig  |
| `net.core.bpf_jit_harden`                 | 0  | 2       | veilig  |
| `net.ipv4.conf.all.log_martians`          | 0  | 1       | veilig  |
| `net.ipv4.conf.default.log_martians`      | 0  | 1       | veilig  |
| `net.ipv4.conf.all.send_redirects`        | 1  | 0       | veilig  |
| `net.ipv4.conf.default.accept_redirects`  | 1  | 0       | veilig  |
| `net.ipv6.conf.all.accept_redirects`      | 1  | 0       | veilig  |
| `net.ipv6.conf.default.accept_redirects`  | 1  | 0       | veilig  |
| `kernel.sysrq`                            | 16 | 0       | laten   |
| `net.ipv4.conf.all.rp_filter`             | 0  | 1       | laten   |
| `kernel.unprivileged_bpf_disabled`        | 2  | 1       | laten   |
| `kernel.modules_disabled`                 | 0  | 1       | nooit   |
| `net.ipv4.conf.all.forwarding`            | 1  | 0       | nooit   |

**De twee "nooit":**

- `kernel.modules_disabled = 1` maakt het laden én ontladen van kernelmodules onmogelijk tot de
  volgende reboot. `hosts/lobos/power-management.nix` doet na resume expliciet
  `modprobe -r ath11k_pci && modprobe ath11k_pci` om de WiFi-driver te herstellen; dat zou stukgaan.
  Ook `nixos-rebuild switch` kan modules nodig hebben. Eén punt is dit niet waard.
- `net.ipv4.conf.all.forwarding = 0` breekt Docker-containernetwerk. De huidige waarde `1` is niet
  per ongeluk: Docker zet die zelf (`modules/wg.nix` zet weliswaar `net.ipv4.ip_forward`, maar die
  module is niet geïmporteerd op lobos).

**De drie "laten":**

- `kernel.sysrq = 0` kost je Alt+SysRq (REISUB). Op een laptop met een gedocumenteerde
  suspend/S0ix-geschiedenis (zie `CLAUDE.md`, sessie 2026-04-09) is een noodklep om een hangende
  machine netjes te syncen en te rebooten meer waard dan één punt.
- `net.ipv4.conf.all.rp_filter = 1` zet strict reverse-path-filtering aan, wat bijt met
  VPN-verkeer en asymmetrische routes. Kan later alsnog, maar hoort een bewuste netwerkkeuze te zijn.
- `kernel.unprivileged_bpf_disabled` staat op `2`; het profiel wil exact `1`. Waarde `2` is in de
  praktijk niet zwakker. Dit is een cosmetisch punt en geen echte verbetering.

### Beslissing 4: geen malware-scanner, `modules/hardening.nix` verwijderen

**Toegevoegd tijdens de uitvoering (2026-09-15).** De oorspronkelijke opzet was `modules/hardening.nix`
activeren om chkrootkit te installeren (`HRDN-7230`, +2). Bij de eerste dry-build bleek dat niet te
kunnen:

```
error: chkrootkit has been removed as it is unmaintained and archived
       upstream and didn't even work on NixOS
```

`rkhunter` bestaat evenmin nog in nixpkgs 26.05. Van de scanners die lynis herkent — chkrootkit,
rkhunter, LMD, ClamAV en een reeks commerciële producten — is alleen **ClamAV** nog beschikbaar.

Dat scherpt de oorspronkelijke bevinding aan: de module was niet alleen niet-geïmporteerd, hij was
al langer onbouwbaar. Upstream vermeldt er expliciet bij dat chkrootkit *op NixOS überhaupt niet
werkte*, dus er is feitelijk nooit iets gemist.

**Gekozen:** geen scanner toevoegen en `modules/hardening.nix` uit de repo verwijderen.
`HRDN-7230` blijft op 1/3 staan; de change levert +19 in plaats van +21.

**Overwogen en verworpen:**

- *ClamAV met freshclam* — geeft de 2 punten en is een echte scanner, maar kost een
  signature-database van rond de gigabyte plus periodieke updates. Op een Linux-werkstation vangt
  ClamAV vooral Windows-malware in bestanden die je doorstuurt. Dat is precies het type daemon dat
  dit ontwerp elders (beslissing 5: AIDE, USBGuard, process accounting) bewust weert.
- *ClamAV zonder freshclam* — goedkoper, maar een scanner zonder actuele signatures vindt niets.
  Dat levert de auditpunten op zonder de bijbehorende bescherming: schijnzekerheid, en daarmee
  erger dan geen scanner.

De consistente uitkomst is de derde: erkennen dat deze host geen malware-scanner heeft, en de dode
code weghalen in plaats van hem te vervangen door iets wat er alleen maar uitziet als een oplossing.

### Beslissing 5: buiten scope, met reden

Deze tests verliezen punten maar krijgen in deze change geen wijziging. Samen ~27 punten.

| Test      | Winst | Waarom niet nu                                          |
|-----------|-------|---------------------------------------------------------|
| FINT-4350 | +5    | AIDE; `/nix/store` is al immutable en te verifiëren met  |
|           |       | `nix store verify --all`. Dagelijkse I/O voor een        |
|           |       | garantie die je grotendeels al hebt.                     |
| AUTH-9286 | +6    | `PASS_MIN_DAYS`/`PASS_MAX_DAYS`; wachtwoordveroudering   |
|           |       | op een single-user laptop is beleid, geen quick-win.     |
| AUTH-9408 | +3    | Logging van mislukte logins; vraagt uitzoekwerk over     |
|           |       | faillog/lastlog op NixOS.                                |
| KRNL-5820 | +3    | Core dumps uitzetten; kost je crash-diagnose.            |
| USB-2000  | +3    | USB-autorisatie op een laptop waar je dagelijks sticks   |
|           |       | in prikt is een slechte ruil.                            |
| SSH-7440  | +2    | `AllowGroups`; zinvol, maar hoort bij de sshd-beslissing |
|           |       | hieronder.                                               |
| BANN-7126 | +2    | Legal banner met ≥5 trefwoorden; theater op een          |
|           |       | persoonlijke machine.                                    |
| AUTH-9230 | +2    | `SHA_CRYPT_*_ROUNDS` terwijl `ENCRYPT_METHOD` op         |
|           |       | `YESCRYPT` staat — lynis grept alleen, de instelling     |
|           |       | doet feitelijk niets.                                    |
| ACCT-9622 | +1    | Process accounting; continue schrijfbelasting.           |

**Nul punten, niet doen:** `NETW-3200` (dccp/sctp/rds/tipc blacklisten), `PKGS-7398`
(`vulnix` ís geïnstalleerd, lynis kent het niet), `ACCT-9626` (sysstat), `FILE-6354` (oude
`/tmp`-bestanden) en `FILE-6310` (aparte partities) hebben in de broncode géén `AddHP`. Vier van de
dertig suggesties zijn die protocol-blacklists; ze ogen als laaghangend fruit en leveren niets op.

## Risks / Trade-offs

**De index meet niet wat je denkt.** Twee observaties die deze change bewust níet adresseert:

- **Je hebt hardening waar lynis geen punt voor geeft.** `/proc` is gemount met
  `hidepid=invisible` (`hosts/lobos/configuration.nix`), zodat users elkaars processen niet zien.
  Lynis scoort dat nergens.
- **Lynis scoort de grootste werkelijke zwakte niet.** `hosts/lobos/sudo-nopasswd.nix` is
  geïmporteerd en zet `security.sudo.wheelNeedsPassword = false`; tegelijk is
  `services.openssh.enable = true` en draait sshd. `AUTH-9250` controleert alleen de *permissies*
  van `/etc/sudoers`, niet de inhoud — NOPASSWD-wheel kost dus nul strafpunten, terwijl het betekent
  dat één gecompromitteerd gebruikersproces zonder prompt root wordt.

  Dat is een verdedigbare afweging op een single-user machine achter NAT, en hij is in de repo
  bewust en gedocumenteerd gemaakt. Maar als het doel "veiliger" is in plaats van "hogere score",
  dan is dít de knop. Bewust buiten deze change gehouden zodat de afweging apart gemaakt kan worden
  en niet meelift op een reeks scorepunten.

**Dode configuratie is het echte patroon.** `modules/hardening.nix` stond klaar maar werd nooit
geïmporteerd — en bleek bij aanraking zelfs niet meer te bouwen; auditd stond aan maar zonder regels; `security.pam.loginLimits` staat
uitgecommentarieerd in `configuration.nix` met `PASS_MAX_DAYS`-items die daar sowieso niet werken
(`loginLimits` schrijft `limits.conf`, niet `login.defs` — de juiste optie is
`security.loginDefs.settings`). Die uitgecommentarieerde poging opruimen of corrigeren hoort bij
deze opschoning, ook al levert het geen punten op.

## Migration Plan

Eén `nixos-rebuild switch`. Alle wijzigingen zijn declaratief en terug te draaien door de commit te
reverten. De sysctl-waarden zijn direct actief; de chkrootkit-timer start bij de eerstvolgende
`daily`-trigger.

Verificatie loopt via een herhaalde lynis-run: de index moet van 64 naar circa 72 gaan, en
`firewall_installed`/`FIRE-4590` moeten omslaan naar actief.

## Open Questions

- Hoe uitgebreid moet de audit-ruleset zijn voordat de ruis/belasting niet meer in verhouding staat
  tot de opbrengst op een desktop? (Zie beslissing 2 — terugvaloptie is auditd uitzetten.)
- Wordt de sudo/sshd-postuur een aparte change, of blijft het een bewust geaccepteerd risico?
- Blijft lobos zonder malware-scanner, of wordt ClamAV alsnog een losse afweging? (Zie beslissing 4.)
