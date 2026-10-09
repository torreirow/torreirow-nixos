# Nix-build-throttling op lobos

SCHED_IDLE voor de nix-daemon + eval-fase-alias, tegen vastlopende sessies tijdens builds.

> Verplaatst uit CLAUDE.md (Huidige Status) om de sessie-context slank te houden.

### Sessie 2026-09-07 - Nix-build-throttling op lobos (sessies liepen vast tijdens builds) - OPGELOST

**Klacht:** Meerdere `claude-code`-sessies (3-5, in tmux) leken vast te lopen zodra ergens een
`nix build`/`nixos-rebuild` liep. OpenSpec change `throttle-nix-builds`.

**Diagnose (gemeten, niet gegokt):** lobos is een **ThinkPad met een mobiele APU** (AMD Ryzen 7
PRO 7840U, 8c/16t, 15-28W — de doc zei eerder "Desktop", klopt niet). Geen OOM (58 GB RAM, ruim
vrij). De nix-daemon draaide **ongeremd**: `CPUSchedulingPolicy=0` (SCHED_OTHER), `max-jobs=16`,
`cores=0` (∞) → tot ~256 build-threads. Met `stress-ng --cpu 16` (120s) + een monitor op k10temp/
klok gemeten: chip zakt van **~5041 → ~3418 MHz (32% klokverlies)**, piek **87 °C**, en de throttle
**verdiept over tijd** door heat-soak in de behuizing. Elke interactieve taak deelt die 32%-straf
mee → "vastlopen" = CPU-verhongering + thermal throttling, niet geheugen en niet netwerk/upload.
Afkoeling na load weg: 87 → 62 °C in ~30s (koeling zelf is prima; het is puur *sustained* load).

**Fix (declaratief, `hosts/lobos/configuration.nix`):**
- `nix.daemonCPUSchedPolicy = "idle";` → SCHED_IDLE: build wijkt voor élk interactief proces,
  krijgt alleen CPU die niemand anders wil. Bij idle machine draait de build alsnog vol.
- `nix.daemonIOSchedClass = "idle";` → idle I/O-klasse voor de LUKS `/nix/store` (disk-contentie).
- `nix.settings.max-jobs = 6;` + `nix.settings.cores = 3;` → thermisch vangnet (was 16/∞).
- **Eval-fase-alias** (`home/zsh.nix`): `nixos-rebuild="nice -n 15 ionice -c3 sudo nixos-rebuild"`.
  De eval-fase draait in het `nixos-rebuild`-proces zelf (niet de daemon) en ontsnapt aan
  SCHED_IDLE. **Let op:** sudo zit ín de alias, want een alias expandeert niet achter `sudo` →
  draai `nixos-rebuild switch ...` **zonder** sudo; nice/ionice erven door naar sudo → de eval.

**Geverifieerd na switch:** `systemctl show nix-daemon.service` → `CPUSchedulingPolicy=5` (SCHED_IDLE),
`IOSchedulingClass=3` (idle); `nix show-config` → `max-jobs = 6`, `cores = 3`.

**Buiten scope (bewust):** ACPI power-profiel (stond op `performance`; bepaalt het totale
vermogens/hitte-budget, complementair aan SCHED_IDLE — `balanced` maakt builds koeler, `low-power`
knijpt óók je sessies af = verkeerde trade) en fysieke koeling (koelstandaard = hardware-plafond
omhoog, complementair). SCHED_IDLE verdeelt binnen het budget; het power-profiel bepaalt het budget.

**Status:** ✅ Live en geverifieerd. Optioneel nog: temp/klok her-meten bij de eerstvolgende echte build.
