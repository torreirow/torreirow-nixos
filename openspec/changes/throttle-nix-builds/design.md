## Context

Zie `proposal.md - Why` voor de motivatie en de meetdata. Relevante huidige staat:

- `nix-daemon.service` draait met `CPUSchedulingPolicy=0` (SCHED_OTHER), `Nice=0`,
  `IOSchedulingClass=2` (best-effort) — geen enkele demping.
- Effectieve nix-settings: `max-jobs=16`, `cores=0` (oneindig) → tot ~256 build-threads mogelijk.
- cgroups v2 actief; NixOS 26.05; config voor lobos in `hosts/lobos/`.
- NixOS biedt de first-class opties `nix.daemonCPUSchedPolicy`, `nix.daemonIOSchedClass` en
  `nix.settings.{max-jobs,cores}`. `nix.daemonCPUSchedPolicy` wordt door NixOS vertaald naar
  `CPUSchedulingPolicy=` op de systemd-unit van de daemon.

## Goals / Non-Goals

**Goals:**

- Build-werk (de daemon-fase) laten wijken voor interactieve processen op CPU én I/O.
- De thermische piek van een build op de laptop-APU begrenzen via minder parallelisme.
- Declaratief, via bestaande NixOS-opties, geen imperatieve systemd-overrides.

**Non-Goals:**

- Het ACPI/power-profiel wijzigen (blijft handmatig `performance`/`balanced`).
- Fysieke koeling / koelstandaard (hardware, buiten NixOS).
- Andere hosts dan lobos aanpassen.

## Decisions

### Beslissing 1: SCHED_IDLE op de daemon i.p.v. nice/CPUWeight/CPUQuota/cpuset

`nix.daemonCPUSchedPolicy = "idle"` (SCHED_IDLE) laat de build alleen CPU krijgen die geen enkel
ander runnable proces wil. Dat geeft het gewenste "optimum": geen snelheidsverlies bij idle, directe
voorrang voor Claude zodra je werkt.

Alternatieven overwogen:
- **`Nice=19`**: helpt, maar SCHED_OTHER blijft de build een gegarandeerd (klein) aandeel geven —
  minder scherp dan SCHED_IDLE.
- **cgroup `CPUWeight` laag**: zachte prioriteit, maar nog steeds gedeeld onder contentie.
- **`CPUQuota`/`AllowedCPUs` (cpuset)**: harde cap/partitie — verspilt capaciteit bij idle en is
  rigide; strijdig met "optimum".

SCHED_IDLE is de scherpste keuze voor het doel en is een one-liner via de NixOS-optie.

### Beslissing 2: I/O ook op idle

`nix.daemonIOSchedClass = "idle"`. De store staat op een LUKS-versleutelde NVMe; zware build-I/O kan
interactieve sessies laten haperen los van CPU. De idle I/O-klasse wijkt net als SCHED_IDLE.

### Beslissing 3: `max-jobs = 6`, `cores = 3` als thermisch vangnet

SCHED_IDLE beschermt responsiviteit, maar niet de thermische heat-soak (gemeten: throttle verdiept
over tijd). Minder threads = lagere piek en tragere opwarming. `6 × 3 = max 18` build-threads op
8c/16t is een bewuste, conservatieve keuze voor een 15-28W laptop-APU; ruim genoeg voor doorvoer,
laag genoeg om de diepe throttle te vermijden. Waarden zijn een afstemming, geen harde eis — de spec
legt "begrensd" vast, niet de exacte getallen.

### Beslissing 4: eval-fase-alias — opgenomen als aparte, optionele taak

De eval-fase draait in het `nixos-rebuild`-proces (jouw shell), niet in de daemon, en ontsnapt dus
aan SCHED_IDLE. Een shell-alias `nice -n 15 ionice -c3 nixos-rebuild …` dekt die laatste ~10% af.
Dit is een dotfile/user-env-wijziging, geen systeemconfig, en raakt de spec-requirements niet.
Daarom als **losse, optioneel af te vinken taak** in tasks.md, zodat de kern-change (daemon +
settings) zelfstandig valide en toepasbaar is.

## Risks / Trade-offs

- **Build trager tijdens actief werk** → Bewust en gewenst; dat is precies het doel. Bij idle
  nagenoeg geen verlies.
- **SCHED_IDLE dekt de eval-fase niet** → Afgedekt door de optionele alias (Beslissing 4); zonder de
  alias blijft de eval-fase op normale prioriteit, wat een kortere, mildere piek is dan de build-fase.
- **`max-jobs`/`cores`-getallen kunnen suboptimaal blijken** → Waarden staan geïsoleerd in
  `hosts/lobos/` en zijn triviaal bij te stellen; de spec bindt alleen aan "begrensd".
- **Interactie met het power-profiel** → Buiten scope; `performance`/`balanced` blijven leidend voor
  het totale vermogensbudget. SCHED_IDLE verdeelt binnen dat budget en is er onafhankelijk van.
