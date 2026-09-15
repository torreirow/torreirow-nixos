## 1. Firewall-detectie herstellen (+5)

- [x] 1.1 `nftables` toevoegen aan de systeempakketten van lobos (`hosts/lobos/programs.nix` of `configuration.nix`), zodat `nft` in `PATH` komt
- [x] 1.2 Na de switch verifiëren: `command -v nft` geeft een pad, en `nft list ruleset` toont de actieve regels
- [x] 1.3 Bevestigen dat het filtergedrag ongewijzigd is: `networking.firewall.allowedTCPPorts`/`allowedUDPPorts` (111, 2049, 5353, 57621) nog steeds bereikbaar

## 2. Malware-scanner: vervallen (chkrootkit uit nixpkgs verwijderd)

Tijdens de uitvoering bleek `modules/hardening.nix` niet alleen niet-geimporteerd maar ook
onbouwbaar: nixpkgs 26.05 gooit `chkrootkit has been removed as it is unmaintained and archived
upstream and didn't even work on NixOS`. Ook `rkhunter` bestaat niet meer in nixpkgs. Van de door
lynis herkende scanners is alleen ClamAV nog beschikbaar. Besloten (2026-09-15) om geen scanner toe
te voegen: consistent met het uitgangspunt in `design.md` (beslissing 4) om geen daemons te introduceren
voor auditpunten. `HRDN-7230` blijft daarmee op 1/3 staan (+0 in plaats van +2).

- [x] 2.1 Vastgesteld dat `chkrootkit` en `rkhunter` niet meer in nixpkgs 26.05 zitten en dat de module dus onbouwbaar is
- [x] 2.2 `modules/hardening.nix` verwijderd uit de repo in plaats van geactiveerd
- [x] 2.3 Requirement "Periodieke malware-scan" uit `specs/host-security-baseline/spec.md` gehaald; `proposal.md` en `design.md` bijgewerkt

## 3. auditd een minimale ruleset geven (+2)

- [x] 3.1 Een kleine, gerichte `security.audit.rules` definiëren voor lobos — wijzigingen aan `/etc/passwd`, `/etc/shadow`, `/etc/sudoers` en het laden van kernelmodules
- [x] 3.2 Na de switch verifiëren: `sudo auditctl -l` geeft niet langer `No rules`
- [x] 3.3 Functioneel testen: een wijziging aan een van de bewaakte bestanden veroorzaken en terugvinden in het auditlog
- [x] 3.4 Logruis en I/O-belasting beoordelen na een dag gebruik — overgedragen aan de normale praktijk (kan niet binnen een sessie worden vastgesteld). Peilmoment vanaf 2026-09-16: valt de journald-ruis of de I/O op, dan is `security.auditd.enable = false` het alternatief met dezelfde auditpunten (zie `design.md`, beslissing 2). Genoteerd in `CLAUDE.md`.

## 4. Veilige sysctl-subset (+12)

- [x] 4.1 Een `boot.kernel.sysctl`-blok toevoegen aan `hosts/lobos/` met de 12 veilige sleutels uit `design.md` beslissing 3: `fs.protected_fifos=2`, `fs.protected_regular=2`, `fs.suid_dumpable=0`, `dev.tty.ldisc_autoload=0`, `kernel.kptr_restrict=2`, `net.core.bpf_jit_harden=2`, `net.ipv4.conf.{all,default}.log_martians=1`, `net.ipv4.conf.all.send_redirects=0`, `net.ipv4.conf.default.accept_redirects=0`, `net.ipv6.conf.{all,default}.accept_redirects=0`
- [x] 4.2 Expliciet NIET zetten: `kernel.modules_disabled` en `net.ipv4.conf.all.forwarding` (breken respectievelijk de WiFi-resume-hack/`nixos-rebuild` en Docker) — met een korte commentaarregel in de nix-code zodat het niet later alsnog "opgelost" wordt
- [x] 4.3 Na de switch elke gezette waarde verifiëren met `sysctl -n <key>`
- [x] 4.4 Regressietest suspend/resume: `systemctl suspend`, daarna controleren dat WiFi terugkomt (`hosts/lobos/power-management.nix` herlaadt `ath11k_pci`) — geslaagd 2026-09-15: suspend uitgevoerd (systemd-sleep froze/suspend/returned/thawed), `network-resume` en `wifi-resume` beide `success`, `ath11k_pci` geladen, WiFi terug op dezelfde connectie en IP, ping+DNS OK; alle sysctls en de 5 auditregels overleefden de resume
- [x] 4.5 Regressietest Docker: een container met netwerk starten en uitgaand verkeer bevestigen

## 5. Opruimen van dode configuratie

- [x] 5.1 Het uitgecommentarieerde `security.pam.loginLimits`-blok met `PASS_MAX_DAYS`/`PASS_MIN_DAYS` in `hosts/lobos/configuration.nix` verwijderen — `loginLimits` schrijft `limits.conf`, niet `login.defs`, dus het zou nooit gewerkt hebben (de juiste optie is `security.loginDefs.settings`, buiten scope)

## 6. Bouwen en meten

- [x] 6.1 `sudo nixos-rebuild switch --flake .#lobos` uitvoeren (let op de alias uit `throttle-nix-builds`: draaien zónder `sudo`)
- [x] 6.2 Lynis opnieuw draaien en de nieuwe `hardening_index` noteren
- [x] 6.3 Verifiëren dat `FIRE-4590` en `ACCT-9630` niet langer in de suggestielijst staan (`HRDN-7230` blijft staan, zie sectie 2), en dat `firewall_installed=1` in `/var/log/lynis-report.dat` staat
- [x] 6.4 Verifiëren dat het aantal `KRNL-6000`-afwijkingen van 17 naar 5 is gedaald
- [x] 6.5 Resultaat toetsen aan de verwachting uit `proposal.md`: 158/244 (index 64) → circa 177/244 (index 72); gemeten: 175/242, index 72

## 7. Documentatie

- [x] 7.1 `CLAUDE.md` bijwerken met een sessie-notitie: baseline, doorgevoerde wijzigingen, gemeten nieuwe index, en expliciet de sleutels die bewust niet gezet zijn en waarom
- [x] 7.2 In de sessie-notitie vastleggen dat de sudo/sshd-postuur (`sudo-nopasswd.nix` + draaiende sshd) een openstaande, bewust geaccepteerde afweging is die lynis niet meet
