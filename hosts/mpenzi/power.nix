# Slaapstand op de IdeaPad 5 14ARE05 (BIOS DTCN24WW, alleen s2idle).
#
# Wekken kan met toets, touchpad, deksel of de aan/uit-knop. Maar udev laadt naast `button` ook
# `tiny_power_button` (alias acpi*:LNXPWRBN:*), en die stuurt bij elke druk zelf SIGRTMIN+4 naar
# PID 1: poweroff, buiten logind en Plasma om, dus ook bij de wek-druk. Het uitzetten bleef dan
# hangen op de bevroren sessies. Gezien op 2026-11-05 (SIGRTMIN+4 vlak na "PM: suspend entry", geen logind-melding).
#
# Zonder tiny_power_button is de knop een gewone toets (KEY_POWER) voor logind/Plasma; logind
# negeert hem vlak na het wekken (HoldoffTimeoutSec).
{ ... }:

{
  boot.blacklistedKernelModules = [ "tiny_power_button" ];
}
