{ config, lib, pkgs, ... }:

# Beveiligingsbaseline voor lobos.
#
# Herkomst: OpenSpec change `harden-lobos-lynis`. Alle waarden hieronder zijn
# gekozen op basis van een lynis-audit (3.1.7) die op 2026-09-14 een
# hardening_index van 64 gaf (158/244 punten). Zie design.md van die change
# voor de onderbouwing per sleutel.

{
  ## ------------------------------------------------------------------
  ## Firewall-zichtbaarheid (lynis FIRE-4536 / FIRE-4590)
  ## ------------------------------------------------------------------
  # De firewall op lobos draait al (`networking.firewall.enable = true` in
  # configuration.nix) en de kernel gebruikt nftables: `nf_tables` is geladen
  # en `iptables` is de nf_tables-variant. Audittooling kon dat alleen niet
  # vaststellen, omdat het `nft`-binary niet in PATH stond:
  #
  #   FIRE-4502  grept /proc/config.gz naar CONFIG_IP_NF_IPTABLES; NixOS bouwt
  #              dat als module, niet builtin  -> iptables-tests overgeslagen
  #   FIRE-4536  vereist `nft` in PATH als preconditie -> overgeslagen
  #   FIRE-4590  concludeert daardoor "geen firewall actief"
  #
  # Dit pakket maakt het meetinstrument beschikbaar. Het verandert NIETS aan
  # welk verkeer wordt toegelaten of geblokkeerd.
  environment.systemPackages = with pkgs; [
    nftables
  ];

  ## ------------------------------------------------------------------
  ## Audit-regels (lynis ACCT-9630)
  ## ------------------------------------------------------------------
  # `security.auditd.enable = true` staat in configuration.nix en zet
  # `security.audit.enable` op mkDefault true. Zonder regels draaide de daemon
  # echter met een lege ruleset: wel de overhead, geen opbrengst.
  #
  # Bewust klein gehouden. Een uitgebreide ruleset genereert op een desktop
  # veel ruis en kost merkbaar I/O, wat op deze thermisch krappe APU niet
  # gratis is (zie change `throttle-nix-builds`).
  #
  # Let op: /etc/{passwd,shadow,group,sudoers} zijn op NixOS gewone bestanden
  # (bij activatie gegenereerd), geen store-symlinks -- watch-regels werken dus.
  # /etc/sudoers.d bestaat niet op deze host en is daarom niet opgenomen.
  security.audit.rules = [
    # Wijzigingen aan gebruikers- en groepsadministratie
    "-w /etc/passwd -p wa -k identity"
    "-w /etc/shadow -p wa -k identity"
    "-w /etc/group -p wa -k identity"

    # Wijzigingen aan de sudo-configuratie
    "-w /etc/sudoers -p wa -k privilege"

    # Laden en ontladen van kernelmodules
    "-a always,exit -F arch=b64 -S init_module,finit_module,delete_module -k modules"
  ];

  ## ------------------------------------------------------------------
  ## Kernelparameters (lynis KRNL-6000)
  ## ------------------------------------------------------------------
  # Twaalf van de zeventien afwijkingen uit het lynis-scanprofiel. De vijf
  # overige staan hieronder toegelicht en worden BEWUST niet gezet.
  boot.kernel.sysctl = {
    # Bestandsbescherming in gedeelde directories (/tmp): voorkomt dat een
    # proces via een aangemaakte FIFO of regulier bestand een ander proces
    # laat schrijven naar iets wat het niet verwacht.
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;

    # Geen core dumps van setuid-programma's -- die kunnen geheime inhoud
    # (sleutels, hashes) op schijf achterlaten.
    "fs.suid_dumpable" = 0;

    # Geen automatisch laden van TTY line disciplines; historisch een bron
    # van lokale privilege-escalatie.
    "dev.tty.ldisc_autoload" = 0;

    # Kernel-pointers volledig verbergen. Merkbaar effect: niet-root
    # profiling-tooling (perf) ziet geen kerneladressen meer.
    "kernel.kptr_restrict" = 2;

    # Hardening van de BPF JIT-compiler tegen JIT-spraying.
    "net.core.bpf_jit_harden" = 2;

    # Pakketten met een onmogelijk bronadres loggen.
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.conf.default.log_martians" = 1;

    # ICMP-redirects: niet versturen en niet accepteren. Een werkstation
    # hoort geen router te spelen en hoeft geen routewijzigingen van het
    # netwerk aan te nemen.
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;

    ## ----------------------------------------------------------------
    ## BEWUST NIET GEZET -- niet "vergeten", niet alsnog toevoegen
    ## ----------------------------------------------------------------
    #
    # "kernel.modules_disabled" = 1;
    #   Blokkeert het laden EN ontladen van kernelmodules tot de volgende
    #   reboot. hosts/lobos/power-management.nix doet na resume expliciet
    #   `modprobe -r ath11k_pci && modprobe ath11k_pci` om WiFi te herstellen;
    #   dat zou stukgaan. Ook `nixos-rebuild switch` kan modules nodig hebben.
    #
    # "net.ipv4.conf.all.forwarding" = 0;
    #   Breekt Docker-containernetwerk. De huidige waarde 1 is niet per
    #   ongeluk: Docker zet die zelf.
    #
    # "kernel.sysrq" = 0;
    #   Kost je Alt+SysRq (REISUB). Op een laptop met een gedocumenteerde
    #   suspend/S0ix-geschiedenis is een noodklep om een hangende machine
    #   netjes te syncen en rebooten meer waard dan een auditpunt.
    #
    # "net.ipv4.conf.all.rp_filter" = 1;
    #   Strict reverse-path-filtering bijt met VPN-verkeer en asymmetrische
    #   routes. Kan later alsnog, maar hoort een bewuste netwerkkeuze te zijn.
    #
    # "kernel.unprivileged_bpf_disabled" = 1;
    #   Staat op 2, het scanprofiel wil exact 1. Waarde 2 is in de praktijk
    #   niet zwakker; dit zou een cosmetisch auditpunt zijn, geen verbetering.
  };
}
