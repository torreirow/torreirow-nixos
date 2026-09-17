## 1. Nix-daemon throttling (kern)

- [x] 1.1 In `hosts/lobos/` de optie `nix.daemonCPUSchedPolicy = "idle";` toevoegen (SCHED_IDLE op de daemon)
- [x] 1.2 In `hosts/lobos/` de optie `nix.daemonIOSchedClass = "idle";` toevoegen (idle I/O-klasse)
- [x] 1.3 In `hosts/lobos/` `nix.settings.max-jobs = 6;` en `nix.settings.cores = 3;` toevoegen (naast/in de bestaande `nix.extraOptions`/`nix.settings` in `configuration.nix`)

## 2. Bouwen en verifiëren

- [x] 2.1 `sudo nixos-rebuild switch --flake .#lobos` uitvoeren
- [x] 2.2 Verifiëren dat de daemon-unit de nieuwe waarden heeft: `CPUSchedulingPolicy=5` (SCHED_IDLE), `IOSchedulingClass=3` (idle) — bevestigd
- [x] 2.3 Verifiëren dat de settings actief zijn: `nix show-config` toont `max-jobs = 6`, `cores = 3` — bevestigd
- [x] 2.4 Mechanisme geborgd: `nix-daemon.service` staat op SCHED_IDLE + idle-I/O → alle build-children erven die prioriteit, en `max-jobs=6`/`cores=3` begrenzen de threads. Empirische her-meting van temp/klok kan bij de eerstvolgende echte build (optioneel, niet-blokkerend)

## 3. Optioneel: eval-fase op lagere prioriteit

- [x] 3.1 Shell-alias `nixos-rebuild="nice -n 15 ionice -c3 sudo nixos-rebuild"` toegevoegd in `home/zsh.nix` (sudo in de alias, want een alias expandeert niet achter `sudo`; draai `nixos-rebuild ...` zonder sudo)
- [x] 3.2 home-manager switch geslaagd (exit 0); alias live geverifieerd: `nixos-rebuild='nice -n 15 ionice -c3 sudo nixos-rebuild'`

## 4. Documentatie

- [x] 4.1 `CLAUDE.md` bijgewerkt met sessie-notitie 2026-09-07 (diagnose + meetdata + fix + verificatie)
