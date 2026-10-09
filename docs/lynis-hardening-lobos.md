# Lynis-hardening lobos (index 64 -> 72)

security-hardening.nix: firewall-zichtbaarheid, auditregels, sysctls, en wat bewust NIET gezet is.

> Verplaatst uit CLAUDE.md (Huidige Status) om de sessie-context slank te houden.

### Sessie 2026-09-15 - Lynis-hardening lobos (index 64 -> 72) - OPGELOST

**Doel:** Quick-wins om de lynis hardening-index van lobos te verhogen. OpenSpec change
`harden-lobos-lynis`. Baseline gemeten 2026-09-14: **158/244 = index 64**, 30 suggesties.

**Alle puntenwaardes zijn uit de lynis-broncode zelf gehaald** (`share/lynis/include/tests_*`,
de `AddHP`-aanroepen) -- niet geschat. Handig voor een volgende ronde.

**Drie defecten gevonden (geen smaakkwestie):**
- **Firewall werd niet gedetecteerd.** `firewall_installed=0` terwijl `networking.firewall.enable`
  aan stond. Oorzaak is NixOS-specifiek: `FIRE-4502` grept `/proc/config.gz` naar
  `CONFIG_IP_NF_IPTABLES` (NixOS bouwt dat als *module*, niet builtin) en `FIRE-4536` vereist het
  `nft`-binary in PATH, dat ontbrak. Beide overgeslagen -> `FIRE-4590` gaf `AddHP 0 5`. De kernel
  gebruikte nftables allang (`lsmod` toont `nf_tables`, `iptables --version` = `(nf_tables)`).
  **Fix: `pkgs.nftables` in systemPackages = +5 punten zonder enige gedragsverandering.**
- **`modules/hardening.nix` werd nergens geimporteerd** -> chkrootkit nooit geinstalleerd, timer
  nooit gedraaid. Bij een poging tot activeren bleek de module bovendien **onbouwbaar**: nixpkgs
  26.05 gooit `chkrootkit has been removed as it is unmaintained and archived upstream and didn't
  even work on NixOS`. Ook `rkhunter` bestaat niet meer in nixpkgs. Module **verwijderd** i.p.v.
  geactiveerd; geen scanner toegevoegd (ClamAV was het enige alternatief -- ~1GB signature-DB voor
  2 auditpunten, past niet bij het uitgangspunt "geen daemons voor punten"). `HRDN-7230` blijft 1/3.
- **auditd draaide met een lege ruleset** -- overhead zonder opbrengst, `ACCT-9630` strafte dat af.
  Nu 5 gerichte regels.

**Doorgevoerd (`hosts/lobos/security-hardening.nix`, nieuw):**
- `pkgs.nftables` in systemPackages (firewall-zichtbaarheid).
- `security.audit.rules`: watches op `/etc/{passwd,shadow,group,sudoers}` + `init_module`/
  `finit_module`/`delete_module`. Let op: die `/etc`-bestanden zijn op NixOS **gewone bestanden**
  (bij activatie gegenereerd), geen store-symlinks -- watch-regels werken dus.
  `security.auditd.enable` zet `security.audit.enable` op `mkDefault true`; de unit
  `audit-rules-nixos.service` laadt de regels.
- **12 van de 17** afwijkende sysctls gezet (bestandsbescherming, suid-coredumps, kptr_restrict,
  bpf_jit_harden, ICMP-redirects/martians).

**BEWUST NIET GEZET (staat als commentaar in de nix-code, niet later alsnog "oplossen"):**
- `kernel.modules_disabled=1` -> breekt de `modprobe -r ath11k_pci`-resume-hack in
  `power-management.nix` **en** `nixos-rebuild switch`.
- `net.ipv4.conf.all.forwarding=0` -> breekt Docker-containernetwerk.
- `kernel.sysrq=0` (verlies van REISUB), `rp_filter=1` (bijt met VPN), `unprivileged_bpf_disabled`
  (staat op 2, profiel wil exact 1 -- cosmetisch).

**Opgeruimd:** uitgecommentarieerd `security.pam.loginLimits`-blok met PASS_MAX_DAYS/PASS_MIN_DAYS.
Dat zou nooit gewerkt hebben: `loginLimits` schrijft `limits.conf` (ulimits), niet `login.defs`.
De juiste optie is `security.loginDefs.settings` (buiten scope gehouden).

**Geverifieerd na switch:** index **72** (175/242). `firewall_installed=1` +
`firewall_software[]=nftables`; FIRE-4590 en ACCT-9630 uit de suggesties; `auditctl -l` toont 5
regels en een `touch /etc/passwd` werd gevangen onder `key=identity`; alle 12 sysctls correct;
nog exact 5 KRNL-6000-afwijkingen = precies de bewust gelaten sleutels. Docker-regressietest OK
(DNS/HTTP/HTTPS in container). **Let op bij testen:** `neverssl.com` resolvt hier IPv6-only en is
onbereikbaar vanaf de IPv4-only Docker-bridge -- gebruik `example.com`, niet neverssl.

**Wat lynis NIET meet (bewust buiten scope):** `sudo-nopasswd.nix` zet
`security.sudo.wheelNeedsPassword = false` en sshd draait -- `AUTH-9250` checkt alleen de
*permissies* van `/etc/sudoers`, niet de inhoud. Nul strafpunten, terwijl het de grootste
werkelijke escalatieroute op deze host is. Omgekeerd krijgt `/proc` met `hidepid=invisible` geen
enkel punt. De index is geen maat voor de beveiliging.

**Nog open:** ~27 punten in AIDE, USB-autorisatie, wachtwoordbeleid, banner, core dumps en
`AllowGroups` -- per stuk afgewogen in `openspec/changes/harden-lobos-lynis/design.md`
(beslissing 5). Suspend/resume-regressietest geslaagd: resume-services `success`, `ath11k_pci`
geladen, WiFi terug op dezelfde connectie/IP, en sysctls + auditregels overleefden de suspend.

**Peilpunt vanaf 2026-09-16:** let op journald-ruis en I/O van de 5 auditregels. Valt dat tegen,
dan `security.auditd.enable = false` -- dat levert dezelfde auditpunten op (ACCT-9630 accepteert
zowel regels als een uitgezette daemon) zonder de overhead.

**Status:** Live en geverifieerd.
