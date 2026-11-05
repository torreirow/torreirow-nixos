## 1. ML-dienst op lobos

- [x] 1.1 `modules/immich-ml.nix`: systemd-unit `immich-machine-learning` met `unstable.immich.machine-learning`, poort 3003, DynamicUser, cache, lage prioriteit
- [x] 1.2 Import in `hosts/lobos/configuration.nix`
- [x] 1.3 `modules/nebula.nix`: inbound `3003/tcp` van host `malandro` op lobos

## 2. Immich op malandro

- [x] 2.1 `modules/immich.nix`: `machineLearning.enabled = true`, `urls = [ "http://10.77.0.2:3003" ]`, commentaar bijwerken

## 3. Verifiëren

- [x] 3.1 Beide hosts evalueren/bouwen (`nix build .#nixosConfigurations.<host>.config.system.build.toplevel`)
- [x] 3.2 VM-test `checks.x86_64-linux.nebula` uitgebreid: malandro mag bij 3003 op lobos, mpenzi en de underlay niet
- [x] 3.3 ML-binary start lokaal, antwoordt op `/ping` en geeft een CLIP-tekst-embedding (`/predict`)

## 4. Documentatie

- [x] 4.1 `docs/immich.md`: ML-rij, sectie "Machine learning op lobos", controle-commando's
- [x] 4.2 `PORTS.md`: 3003 op lobos
- [x] 4.3 Spec `immich-photos` bijwerken (delta)

## 5. Uitrol (handmatig, door de beheerder)

- [x] 5.1 `sudo nixos-rebuild switch --flake .#lobos`; `systemctl status immich-machine-learning`
- [x] 5.2 Op malandro: `git pull && sudo nixos-rebuild switch --flake .#malandro`; `curl http://10.77.0.2:3003/ping` → pong
- [x] 5.3 Immich: Administratie → Taken → Slim zoeken en Gezichtsdetectie → **Alle**
