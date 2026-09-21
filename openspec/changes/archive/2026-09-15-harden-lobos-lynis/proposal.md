## Why

Een lynis-audit op **lobos** (NixOS 26.05, lynis 3.1.7, scan 2026-09-14) geeft
`hardening_index = 64` — **158 van 244 punten**, met 30 suggesties en 1 warning.

Drie bevindingen uit die audit zijn geen smaakkwestie maar aantoonbare defecten of gratis punten:

1. **De firewall wordt niet gedetecteerd.** `firewall_installed=0` terwijl
   `networking.firewall.enable = true` en `firewall.service` actief is. Oorzaak is een
   NixOS-specifieke detectieketen die breekt: `FIRE-4502` grept `/proc/config.gz` naar
   `CONFIG_IP_NF_IPTABLES` (NixOS bouwt dat als module, niet builtin) en `FIRE-4536` vereist het
   `nft`-binary in `PATH`, dat op lobos ontbreekt. Beide tests worden overgeslagen, waarna
   `FIRE-4590` `AddHP 0 5` toekent. De kernel gebruikt nftables wél — `lsmod` toont `nf_tables` en
   `iptables --version` geeft `v1.8.13 (nf_tables)`. Dit is puur meetfout: **5 punten voor het
   beschikbaar maken van een binary.**

2. **`modules/hardening.nix` is dode, onbouwbare code.** Het bestand definieert chkrootkit plus een
   dagelijkse timer, maar staat in geen enkele `imports`-lijst — `chkrootkit` zit niet in `PATH` en
   de timer heeft nooit gedraaid. Bij een poging tot activeren bleek de module bovendien niet meer
   te bouwen: nixpkgs 26.05 gooit `chkrootkit has been removed as it is unmaintained and archived
   upstream and didn't even work on NixOS`. Ook `rkhunter` is uit nixpkgs verdwenen.

3. **auditd draait met een lege ruleset.** `security.auditd.enable = true` staat in
   `hosts/lobos/configuration.nix`, `auditctl -l` geeft `No rules`. Dat is het slechtste van twee
   werelden: de overhead van een draaiende audit-daemon zonder enige opbrengst. `ACCT-9630` straft
   dit expliciet af met `AddHP 0 2`.

Daarnaast wijken **17 sysctl-sleutels** af van het lynis-scanprofiel (`KRNL-6000`, 1 punt per
sleutel). Twaalf daarvan zijn op een werkstation onschadelijk aan te passen.

## What Changes

- **Firewall-detectie herstellen** — `nftables` toevoegen aan de systeempakketten zodat het
  `nft`-binary in `PATH` staat. `FIRE-4536` detecteert dan de al geladen `nf_tables`-kernelmodule,
  zet `FIREWALL_ACTIVE=1`, en `FIRE-4590` scoort 5/5. Verandert niets aan het feitelijke
  filtergedrag — de firewall draaide al.
- **`modules/hardening.nix` verwijderen** — de module is onbouwbaar geworden en van de door lynis
  herkende scanners is alleen ClamAV nog beschikbaar. Besloten geen scanner toe te voegen (zie
  `design.md`, beslissing 5); dode code die niet meer kán werken hoort uit de repo.
- **auditd een zinnige ruleset geven** — een minimale `security.audit.rules` definiëren, zodat de
  draaiende daemon ook werkelijk iets vastlegt. (Alternatief — auditd uitzetten — levert dezelfde
  punten op; de afweging staat in `design.md`.)
- **Veilige sysctl-subset zetten** — 12 van de 17 afwijkende sleutels via `boot.kernel.sysctl`
  rechttrekken (bestandsbescherming, core-dump-gedrag, kernel-pointer-restrictie, BPF-JIT-hardening
  en het ICMP-redirect/martians-blok).

Verwacht resultaat: **158/244 (index 64) → ~177/244 (index 72)**, zonder enige nieuwe daemon.

## Non-goals

Bewust buiten scope gehouden, met onderbouwing in `design.md`:

- **Twee sysctl-sleutels die lobos zouden breken**: `kernel.modules_disabled = 1` (breekt de
  `modprobe -r ath11k_pci`-resume-hack in `hosts/lobos/power-management.nix` én
  `nixos-rebuild switch`) en `net.ipv4.conf.all.forwarding = 0` (breekt Docker-containernetwerk).
- **Drie discutabele sysctl-sleutels**: `kernel.sysrq`, `net.ipv4.conf.all.rp_filter` en
  `kernel.unprivileged_bpf_disabled`.
- **Nieuwe daemons en beleid**: AIDE (`FINT-4350`), USB-autorisatie (`USB-2000`), process accounting
  (`ACCT-9622`), `login.defs`-wachtwoordbeleid (`AUTH-9230`/`AUTH-9286`), logging van mislukte
  logins (`AUTH-9408`), core-dump-onderdrukking (`KRNL-5820`), `AllowGroups` in sshd (`SSH-7440`) en
  een legal banner (`BANN-7126`). Samen nog eens ~27 punten, maar elk met een eigen afweging.
- **De sudo/sshd-postuur van lobos** — `security.sudo.wheelNeedsPassword = false` via
  `hosts/lobos/sudo-nopasswd.nix`, in combinatie met een draaiende sshd. Lynis scoort dit niet, maar
  het is de grootste werkelijke escalatieroute op deze host. Bewust een aparte beslissing.

## Capabilities

### New Capabilities

- `host-security-baseline`: Legt vast welke controleerbare beveiligingsinstellingen een host minimaal
  voert — firewall-zichtbaarheid, kernelparameters en audit-logging — zodat de postuur declaratief
  is in plaats van impliciet.

### Modified Capabilities

<!-- Geen bestaande capability dekt de beveiligingsbaseline van een host. -->

## Impact

- **Host:** alleen `lobos`. Config landt in `hosts/lobos/` plus het activeren van
  `modules/hardening.nix`.
- **Systeem:** voegt `nftables` toe aan de systeempakketten, zet auditregels actief en past 12
  kernelparameters aan. Verwijdert `modules/hardening.nix`. Actief na `nixos-rebuild switch`.
- **Trade-off:** de sysctl-wijzigingen zijn op een single-user werkstation gedragsneutraal, met als
  enige merkbare effect dat `kptr_restrict = 2` kernel-pointers verbergt voor niet-root
  profiling-tooling (`perf`). De host houdt geen malware-scanner — dat was feitelijk al zo.
- **Meetbaarheid:** verifieerbaar door lynis opnieuw te draaien en de index te vergelijken.
