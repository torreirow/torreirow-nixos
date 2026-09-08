# Tasks — add-torrlinny-web

Spiegelt de child-beans van epic `nixos-anvf`.

## 1. Deploy key (bean nixos-iq76)
- [x] ed25519-keypair genereren
- [x] public key als read-only deploy key op github.com/torreirow/torrlinny
- [x] private key als agenix-secret `secrets/torrlinny-deploy-key.age` + recipient-regel in `secrets/secrets.nix`
- [x] clone-auth end-to-end getest met de deploy key

## 2. Sync/checkout (bean nixos-vegg)
- [x] clone (`--depth 1 --branch main`) via de deploy key naar `${dataDir}/checkout`
- [x] update: fetch + reset --hard origin/main
- [x] service-user `torrlinny` + tmpfiles voor de werkmap

## 3. Build-service (bean nixos-bet5)
- [x] `pkgs.hugo` + `pkgs.pagefind` gebruiken
- [x] overlay + content samenstellen; `hugo --minify` → `pagefind`
- [x] atomic symlink-swap naar `live`; keep-last-good bij een fout
- [x] prune (nieuwste 3 builds)

## 4. Frontend/overlay (bean nixos-0b9m)
- [x] zelfstandige Hugo-overlay (config + layouts + css), PaperMod niet gebruikt
- [x] `data-pagefind-filter` per taxonomie (minify-veilige tekst-inhoud)
- [x] `data-pagefind-sort` op datum (crdate→.Date)
- [x] Pagefind-UI (facet + full-text) + strakke, leesbare layout (light/dark)

## 5. Timer + change-detectie (bean nixos-34vu)
- [x] timer ~elke 3 min, `Persistent`
- [x] `git fetch` + HEAD-compare → build overslaan bij geen wijziging

## 6. Nginx + Authelia (bean nixos-maau)
- [x] vhost `linny.toorren.net`, forceSSL, `useACMEHost "toorren.net"`
- [x] `root = ${dataDir}/live`; Authelia forward-auth

## 7. Verificatie + docs (bean nixos-p9me)
- [x] deploy naar malandro; eerste build produceert de site (rev gepubliceerd, live-symlink)
- [x] end-to-end: 109 notities, 6 facet-filters, 2 sorts (datum+titel), full-text index; nginx leest + 302→Authelia
- [x] atomic swap/keep-last-good in de build-service; change-detectie geverifieerd (build overgeslagen bij geen wijziging)
- [x] `docs/torrlinny.md` + `CLAUDE.md`-verwijzing toegevoegd

## 8. Webhook (bean nixos-bvhd) — DRAFT, buiten deze change
- [ ] (later) GitHub-webhook (HMAC) → build-service; timer als vangnet
