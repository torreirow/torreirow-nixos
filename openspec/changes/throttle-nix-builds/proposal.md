## Why

Op **lobos** (ThinkPad, AMD Ryzen 7 PRO 7840U — een mobiele 8c/16t APU met een 15-28W
vermogensbudget) draait de nix-daemon volledig ongeremd: `CPUSchedulingPolicy=0` (SCHED_OTHER),
`max-jobs=16`, `cores=0` (oneindig). Een `nix build` / `nixos-rebuild` claimt daardoor alle 16
threads op gelijke voet met interactieve processen. Gemeten met een gecontroleerde all-core load
zakt de chip binnen ~40s thermisch terug van **~5041 MHz naar ~3418 MHz (32% klokverlies, piek
87 °C)** en die throttle **verdiept over tijd** door heat-soak in de laptopbehuizing. Gevolg: alle
gelijktijdig draaiende interactieve taken — met name 3-5 `claude-code`-sessies in tmux — delen die
32%-straf mee en lijken vast te lopen zodra er ergens een build start.

## What Changes

- **Nix-daemon op SCHED_IDLE** — `nix.daemonCPUSchedPolicy = "idle"`: build-werk wijkt onmiddellijk
  voor elk interactief proces en krijgt alleen CPU die verder niemand gebruikt. Bij een idle machine
  draait de build alsnog vol; zodra jij werkt, geeft hij voorrang.
- **Disk-I/O van de daemon op idle** — `nix.daemonIOSchedClass = "idle"`: dezelfde wijk-logica voor
  I/O op de LUKS-versleutelde `/nix/store`, zodat build-I/O je interactieve sessies niet verdringt.
- **Parallelisme afgeknepen** — `nix.settings.max-jobs = 6` en `nix.settings.cores = 3`: hoogstens
  ~18 build-threads in plaats van tot ~256, wat de thermische piek en heat-soak op deze laptop-APU
  fors verlaagt (vangnet-laag onder SCHED_IDLE).
- **Open vraag (te beslissen in design):** een optionele shell-alias die óók de **eval-fase** van
  `nixos-rebuild` op lagere prioriteit zet (`nice -n 15 ionice -c3 …`). De eval draait in het
  `nixos-rebuild`-proces zelf, niet in de daemon, en ontsnapt dus aan SCHED_IDLE.

## Capabilities

### New Capabilities

- `nix-build-throttling`: Beheerst hoeveel CPU-, I/O- en thread-budget nix-build-werk op een host
  mag opeisen, zodat builds interactieve processen niet verdringen of thermisch laten throttelen.

### Modified Capabilities

<!-- Geen bestaande capability dekt build-resourcebeheer; niets aan te passen. -->

## Impact

- **Host:** alleen `lobos`. Config landt in `hosts/lobos/` (nieuwe of bestaande nix-instellingen).
- **Systeem:** herconfigureert `nix-daemon.service` (scheduling policy + I/O class) en de
  `nix.settings` (max-jobs, cores). Actief na `nixos-rebuild switch`.
- **Buiten scope:** het ACPI/power-profiel (blijft handmatig `performance`/`balanced`) en fysieke
  koeling (koelstandaard) — beide complementair maar geen onderdeel van deze change.
- **Trade-off:** builds worden trager wanneer je tegelijk actief bent (bewust — dat is het doel);
  op een idle machine blijft de bouwsnelheid nagenoeg gelijk.
