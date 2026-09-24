{ config, lib, pkgs, ... }:

{
  # Suspend-wakeup: interne USB-controllers als wekbron uitzetten.
  #
  # Symptoom (2026-09-22): `systemctl suspend` leek te "blokkeren" -- lobos ging
  # wel slapen maar was na 2-12 s weer wakker. Niets blokkeerde iets:
  # `systemd-inhibit --list` toonde alleen `delay`-inhibitors en
  # /sys/power/suspend_stats gaf `fail: 0`.
  #
  # Werkelijke oorzaak: de twee interne xHCI-controllers XHC0/XHC1 stonden in
  # /proc/acpi/wakeup gearmeerd en vuurden bij elke suspend binnen seconden een
  # ACPI-SCI (IRQ 9). Bewijs: hun ACPI-nodes (\_SB_.PCI0.GP17.XHC{0,1}) liepen in
  # /sys/kernel/debug/wakeup_sources exact op het wekmoment op, voor alle andere
  # resume-events; serio0 (toetsenbord) en i2c-ELAN0688 (touchpad) bewogen pas
  # tientallen seconden na de resume. Hieraan hangen de wireless-receiver-dongle
  # en de Integrated Camera.
  #
  # Gevolg was dubbel: de SoC haalde S0i3 nooit
  # (`amd_pmc: Last suspend didn't reach deepest state`, `total_hw_sleep = 0`,
  # smu_fw_info `Last S0i3 Status: Unknown/Fail`) -- het bleef een lichte
  # idle-lus die elk interrupt openbrak.
  #
  # Na het uitzetten: 7 u 08 m en 43 m 31 m aaneengesloten geslapen,
  # `Last S0i3 Status: Success`, ~100% van de slaapduur daadwerkelijk in S0i3.
  #
  # LET OP: `echo XHC0 > /proc/acpi/wakeup` is een TOGGLE, dus niet idempotent --
  # twee keer schrijven zet hem weer aan. Daarom een udev-regel op het
  # PCI-attribuut: dat is een waarde, geen toggle. Geverifieerd dat het
  # doorwerkt naar de ACPI-vlag: `disabled` naar power/wakeup schrijven zet
  # /proc/acpi/wakeup ook op `*disabled`.
  #
  # Gematcht op vendor/device-id i.p.v. het PCI-adres, zodat een herenumeratie
  # van de bus dit niet stilletjes uitschakelt.
  services.udev.extraRules = ''
    # XHC0 -- pci:0000:64:00.3, AMD Family 19h xHCI
    SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{device}=="0x15b9", ATTR{power/wakeup}="disabled"
    # XHC1 -- pci:0000:64:00.4, AMD Family 19h xHCI
    SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{device}=="0x15ba", ATTR{power/wakeup}="disabled"
  '';

  # BEWUST NIET UITGEZET: XHC3/XHC4 (pci:0000:66:00.{3,4}) zijn de USB4/dock-kant.
  # Die hebben de suspends niet gewekt en zijn de route waarlangs een dock of
  # USB-toetsenbord de laptop juist MOET kunnen wekken. Blijft lobos alsnog
  # spontaan wakker worden, dan zijn dat de volgende verdachten
  # (0x15c0 resp. 0x15c1) -- eerst meten via /sys/kernel/debug/wakeup_sources.
  #
  # LID en SLPB blijven eveneens gearmeerd: deksel open en de slaapknop horen te wekken.
}
