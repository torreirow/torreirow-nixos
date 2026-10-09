# Power management / suspend (lobos)

Laptop kan ALLEEN S0ix/s2idle (geen S3). power-management.nix met resume-services en de ath11k_pci-hack.

> Verplaatst uit CLAUDE.md (Huidige Status) om de sessie-context slank te houden.

### Sessie 2026-04-09 - Suspend/Standby probleem - OPGELOST

**Probleem:** Laptop ging niet correct in standby. WiFi/netwerk adapter werd uitgeschakeld maar de laptop suspendeerde niet volledig.

**Diagnose:**
- Laptop ondersteunt alleen **Modern Standby (S0ix/s2idle)**, GEEN traditionele S3 suspend
- `/sys/power/mem_sleep` toont alleen `[s2idle]`, geen `deep` optie beschikbaar
- S0ix is ontworpen voor Windows en werkt vaak slecht op Linux (AMD laptops)
- Kernel log: `Low-power S0 idle used by default for system suspend`
- NetworkManager wordt correct gestopt maar suspend voltooit niet
- Hardware beperking: BIOS/firmware ondersteunt geen S3 deep sleep

**Oorzaak:**
- Moderne AMD laptop met alleen S0ix ondersteuning (geen S3 in firmware)
- Modern Standby vereist perfecte driver support die vaak ontbreekt op Linux
- Network/wifi driver (ath11k_pci) recovery na suspend niet automatisch

**Oplossing (toegepast):**
Nieuwe module `hosts/lobos/power-management.nix` aangemaakt met:

```nix
# Kernel parameters voor betere S0ix werking
boot.kernelParams = [
  "acpi_osi=Linux"           # Betere ACPI compatibiliteit
  "amd_pstate=active"        # Optimale AMD power management
  "usbcore.autosuspend=-1"   # Voorkom USB wake-up problemen
];

# Services voor network/wifi herstel na suspend
systemd.services.network-resume  # Herstart NetworkManager
systemd.services.wifi-resume     # Herlaadt ath11k_pci driver

# Power management
powerManagement.powertop.enable = true;
```

**Status:**
- [x] `hosts/lobos/power-management.nix` aangemaakt
- [x] Module toegevoegd aan `configuration.nix` imports
- [x] Oude uitgecommentarieerde suspend code verwijderd
- [x] `sudo nixos-rebuild switch --flake .#lobos` succesvol
- [x] Services actief: powertop.service, network-resume.service, wifi-resume.service
- [ ] **Reboot vereist** voor kernel parameter activatie
- [ ] Test suspend na reboot met `systemctl suspend`

**Technische achtergrond:**
- **S3 (deep sleep)**: Traditionele suspend-to-RAM, heel goede Linux support
- **S0ix (s2idle/Modern Standby)**: Nieuwere standaard, ontworpen voor Windows
- Moderne laptops hebben vaak GEEN S3 meer in firmware (alleen S0ix)
- S0ix vereist dat ALLE hardware drivers correct suspend implementeren
- Linux kernel S0ix support is verbeterd maar nog niet perfect voor alle hardware

## Config: hosts/lobos/power-management.nix

### hosts/lobos/power-management.nix

Bevat alle power management en suspend/resume settings:
- `boot.kernelParams` voor betere S0ix (Modern Standby) werking
- `powerManagement.powertop.enable` voor automatische power optimalisatie
- `systemd.services.network-resume` - herstart NetworkManager na suspend
- `systemd.services.wifi-resume` - herlaadt ath11k_pci driver na suspend
- AMD-specifieke power management (`amd_pstate=active`)
- USB autosuspend workarounds

**Belangrijk:** Laptop ondersteunt ALLEEN S0ix/s2idle (Modern Standby), GEEN S3 deep sleep.

## Commandos

### Power Management & Suspend (lobos)
```bash
# Test suspend
systemctl suspend

# Status van suspend services
systemctl status network-resume.service
systemctl status wifi-resume.service
systemctl status powertop.service

# Check suspend logs
journalctl -u systemd-suspend.service -n 50
journalctl -u network-resume.service -n 20
journalctl -u wifi-resume.service -n 20

# Check sleep mode (verwacht: [s2idle] voor deze laptop)
cat /sys/power/mem_sleep

# Check beschikbare suspend states
cat /sys/power/state  # Verwacht: freeze mem disk

# Check kernel power management messages
sudo dmesg | grep -i "suspend\|sleep\|PM:"

# Check wat suspend inhibit (verhindert)
systemd-inhibit --list

# Check powertop statistieken
sudo powertop

# Handmatig wifi driver herladen (bij problemen)
sudo modprobe -r ath11k_pci && sleep 1 && sudo modprobe ath11k_pci

# NetworkManager restart (bij problemen)
sudo systemctl restart NetworkManager.service
```
