# Tasks — add-linny-web-module

Spiegelt de child-beans van epic `nixos-dhh8`. Code leeft in de repo `linny-web-theme`.

## 1. flake.nix (bean nixos-liz3)
- [x] `flake.nix` in `linny-web-theme`: input `nixpkgs` (nixos-26.05)
- [x] output `nixosModules.linny-web = import ./nix/linny-web.nix` + `nixosModules.default`
- [x] plain nix `systems`-map (x86_64-linux, aarch64-linux), geen flake-utils
- [x] `checks.<system>.eval` instantieert een voorbeeldconfig met de module
- [x] `flake.lock` gecommit

## 2. linny-web module (bean nixos-hq2x)
- [x] `nix/linny-web.nix`: options `enable, gitRepo, gitTokenFile, baseURL, webRoot, stateDir, user, interval, themeModule, configFile`
- [x] build-service (oneshot): `hugo mod get` → `hugo build` (`--config`, `--configDir doesnotexist`, `--baseURL`)
- [x] atomic symlink-swap → `webRoot`, keep-last-good, prune (nieuwste 3)
- [x] timer met change-detectie (git HEAD + recept `hugo=<v>;go=<v>`)
- [x] service-user + tmpfiles

## 3. Token-clone + permissies (bean nixos-6uat)
- [x] HTTPS-clone/fetch met een git credential-helper die `gitTokenFile` op auth-tijd leest (token niet in argv/URL/config)
- [x] permissie-model: stateDir `0751`, builds `0755` + `a+rX`, checkout `0700`
- [x] `fence.py`-preprocessing alleen als het bestand bestaat

## 4. Optionele nginx-helper (bean nixos-yyax)
- [x] `services.linny-web.nginx = { enable; virtualHost; useACMEHost; }`
- [x] default uit → geen vhost; kern blijft webserver-agnostisch

## 5. Docs (bean nixos-hez0)
- [x] README "Serve it on NixOS" (minimale config + flake-input + webRoot-koppeling + nginx-helper)
- [x] CHANGELOG-entry

## 6. Verificatie
- [x] `nix flake check` schoon op de theme-repo
- [x] eval van build-service-unit + `webRoot`-optie klopt
