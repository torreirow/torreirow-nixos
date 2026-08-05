## 1. Secrets aanmaken (handmatig, buiten nixos-rebuild)

- [x] 1.1 Genereer Authelia OIDC HMAC secret: `openssl rand -hex 32` → sla op in `secrets/authelia-oidc-hmac-secret.age` via `agenix edit`
- [x] 1.2 Genereer Authelia OIDC issuer private key: `openssl genrsa 4096` → sla op in `secrets/authelia-oidc-issuer-private-key.age` via `agenix edit`
- [ ] 1.3 Kies een Wallos OIDC client secret (willekeurige string) en genereer de argon2id hash: `authelia crypto hash generate argon2 --password '<secret>'` — noteer beide
- [ ] 1.4 Maak `secrets/wallos-env.age` aan via `agenix edit` met: `DB_DRIVER=mysql`, `DB_HOST=host.docker.internal`, `DB_PORT=3306`, `DB_NAME=wallos`, `DB_USER=wallos`, `DB_PASSWORD=<kies>`, `OIDC_CLIENT_SECRET=<plain-secret uit 1.3>`, `TZ=Europe/Amsterdam`
- [ ] 1.5 Voeg alle drie nieuwe secrets toe aan `secrets/secrets.nix` (of equivalent) zodat ze encryptbaar zijn voor de juiste SSH keys

## 2. MariaDB uitbreiden (modules/mariadb.nix of wallos.nix)

- [x] 2.1 Voeg `services.mysql.settings.mysqld.bind-address = "0.0.0.0"` toe aan `modules/mariadb.nix`
- [x] 2.2 Voeg iptables-regels toe voor Docker bridge toegang tot poort 3306 (patroon uit `modules/postgres.nix`)

## 3. Authelia OIDC activeren (modules/authelia.nix)

- [x] 3.1 Uncommenteer de `authelia-oidc-hmac-secret` en `authelia-oidc-issuer-private-key` secrets in `age.secrets`
- [x] 3.2 Uncommenteer en activeer de `oidcHmacSecretFile` en `oidcIssuerPrivateKeyFile` in `services.authelia.instances.main.secrets`
- [x] 3.3 Uncommenteer en configureer de `identity_providers.oidc` sectie met `cors` settings
- [ ] 3.4 Voeg de Wallos OIDC client toe: `id = "wallos"`, `secret = "<argon2id-hash uit 1.3>"`, `redirect_uris = ["https://subscriptions.toorren.net/index.php"]`, `scopes = ["openid" "email" "profile"]`, `authorization_policy = "two_factor"`

## 4. Wallos module aanmaken (modules/wallos.nix)

- [x] 4.1 Maak `modules/wallos.nix` aan met `age.secrets.wallos-env` definitie
- [x] 4.2 Voeg OCI container configuratie toe: image `bellamy/wallos:latest`, port `127.0.0.1:8095:80`, twee volumes, `--add-host=host.docker.internal:host-gateway`, `--env-file`
- [x] 4.3 Voeg OIDC env vars toe aan de container: `OIDC_ENABLED=true`, `OIDC_PROVIDER_NAME=Authelia`, `OIDC_CLIENT_ID=wallos`, `OIDC_ISSUER=https://auth.toorren.net`, `OIDC_AUTH_URL=https://auth.toorren.net/api/oidc/authorization`, `OIDC_TOKEN_URL=https://auth.toorren.net/api/oidc/token`, `OIDC_USERINFO_URL=https://auth.toorren.net/api/oidc/userinfo`, `OIDC_REDIRECT_URL=https://subscriptions.toorren.net/index.php`, `OIDC_LOGOUT_URL=https://auth.toorren.net/logout`, `OIDC_DISABLE_PASSWORD_LOGIN=true`, `OIDC_AUTO_CREATE_USER=true`
- [x] 4.4 Voeg MariaDB `ensureDatabases` en `ensureUsers` toe (via `lib.mkAfter`, patroon uit `vikunja.nix`)
- [x] 4.5 Voeg `systemd.tmpfiles.rules` toe voor `/data/external/wallos/db` en `/data/external/wallos/logos`
- [x] 4.6 Voeg nginx virtualHost toe voor `subscriptions.toorren.net`: transparante proxy naar `127.0.0.1:8095`, `useACMEHost = "toorren.net"`, `forceSSL = true`, geen forward-auth

## 5. Integreren in malandro configuratie

- [x] 5.1 Voeg `./wallos.nix` toe aan imports in `hosts/malandro/configuration.nix`
- [x] 5.2 Voeg poort 8095 toe aan `PORTS.md` (Wallos, 127.0.0.1, Docker)

## 6. Deployen en testen

- [ ] 6.1 Voer `sudo nixos-rebuild switch --flake .#malandro` uit
- [ ] 6.2 Controleer of de wallos container draait: `sudo docker ps | grep wallos`
- [ ] 6.3 Controleer MariaDB bereikbaar van Docker: `sudo docker exec wallos mysql -h host.docker.internal -u wallos -p wallos -e "SELECT 1;"`
- [ ] 6.4 Controleer Authelia OIDC endpoint: `curl https://auth.toorren.net/.well-known/openid-configuration`
- [ ] 6.5 Test login flow: open https://subscriptions.toorren.net → verwacht redirect naar Authelia → na login terugkeer naar Wallos
- [ ] 6.6 Voltooi de Wallos setup wizard (currency instellen, eerste abonnement toevoegen)
