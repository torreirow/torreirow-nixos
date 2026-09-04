# Tasks — migrate-torrlinny-to-linny-web

Spiegelt de child-beans van feature `nixos-9596`.

## 1. SSH-auth in de gedeelde module (bean nixos-3o4y, repo linny-web-theme)
- [x] `gitTokenFile` + `gitSshKeyFile` beide `nullOr`, assertion "precies één"
- [x] SSH-modus: `GIT_SSH_COMMAND` (`-i` key, `IdentitiesOnly`, known_hosts in stateDir), git_auth zonder credential-helper
- [x] README/optietabel + CHANGELOG + flake-check (beide auth-modi) bijgewerkt
- [x] commit + push (`506ba2e`)

## 2. flake-input + module in malandro-lijst (bean nixos-l2rf)
- [x] `inputs.linny-web.url = github:torreirow/linny-web-theme` + in `outputs`-destructurering
- [x] `inputs.linny-web.nixosModules.linny-web` in de malandro modules-lijst
- [x] `flake.lock` gepind op `506ba2e`

## 3. torrlinny.nix als thin wrapper (bean nixos-oosu)
- [x] behoud `options.services.torrlinny.{enable,domain,acmeHost}`
- [x] config: agenix deploy-key + `services.linny-web` (gitSshKeyFile, user/stateDir/webRoot/baseURL)
- [x] `SupplementaryGroups = [ "keys" ]` op `linny-web-build`
- [x] eigen Authelia-vhost (autheliaVerifyLocation/autheliaAuthConfig), root = webRoot
- [x] oude user/tmpfiles/service/timer/buildScript verwijderd

## 4. build + switch + verificatie (bean nixos-6j79)
- [x] `nixos-rebuild dry-build` schoon
- [x] `switch` schoon; `linny-web-build` bouwt (rev 6c5906f via SSH-deploy-key)
- [x] live-symlink ok; checkout `0700`; werkmap `0751`; output leesbaar
- [x] `curl linny.toorren.net` → `302 → auth.toorren.net` (Authelia)
- [x] oude `torrlinny-build`-units weg; `docs/torrlinny.md` bijgewerkt
