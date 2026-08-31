# nextcloud-sync (home-manager module)

Headless Nextcloud-sync per user met `nextcloudcmd` (uit `pkgs.nextcloud-client`).
Geen GUI/tray: elke sync is een oneshot `systemd.user.service` die door een
`systemd.user.timer` periodiek wordt getriggerd.

## Waarom `nextcloudcmd` en niet de GUI-client

`nextcloudcmd` is one-shot: hij synct één keer lokaal ↔ remote en stopt. Ideaal
om onder een timer te hangen, werkt zonder grafische sessie, geen tray-icon.

## Credentials — belangrijk

`nextcloudcmd --non-interactive` leest `$NC_USER` en `$NC_PASSWORD` uit de
environment. Die komen uit een **handmatig** aangemaakt EnvironmentFile:

```bash
install -m 600 /dev/stdin ~/.config/nextcloud-sync/credentials <<'EOF'
NC_USER=jouw-gebruiker
NC_PASSWORD=jouw-app-password
EOF
```

- Gebruik een **Nextcloud app-password** (Instellingen → Beveiliging → Apparaten
  & sessies), nooit je hoofdwachtwoord. Een app-password is scoped en
  revocable.
- Het bestand wordt **bewust niet** door Nix beheerd. Zet het credential
  **NOOIT** via `home.file.".../credentials".text = "..."` — dan belandt het
  wereld-leesbaar (0444) in de nix-store én in git. Dat is strikt slechter dan
  welke secret-manager dan ook.
- Een `credentials.example` met placeholders wordt wel door de module
  neergezet, puur als sjabloon.

## Gebruik

Importeer de module in je home-manager config en configureer:

```nix
services.nextcloud-sync = {
  enable = true;
  # credentialsFile = "~/.config/nextcloud-sync/credentials";  # default
  syncs = {
    docs = {
      serverUrl = "https://cloud.example.com";
      localPath = "~/Nextcloud";
      interval  = "10min";     # OnUnitActiveSec: interval ná vorige run
      # remotePath = "/";      # optioneel: remote submap (--path)
      # excludeFile = "~/.config/nextcloud-sync/exclude.lst";
      # trust = false;          # alleen voor self-signed test-servers
    };
  };
};
```

Elke sleutel onder `syncs` levert een aparte service + timer:
`nextcloud-sync-<naam>.service` / `.timer`.

## Verifiëren

```bash
systemctl --user list-timers | grep nextcloud-sync
systemctl --user start nextcloud-sync-docs.service   # handmatige run
journalctl --user -u nextcloud-sync-docs.service -n 50
```

Als het credentials-bestand ontbreekt of leeg is, faalt de service met een
duidelijke melding uit `ExecStartPre` (het `-` vóór de EnvironmentFile maakt het
bestand optioneel zodat die melding ook echt verschijnt).

## Opties

| Optie                  | Default                                  | Betekenis                                  |
|------------------------|------------------------------------------|--------------------------------------------|
| `enable`               | `false`                                  | Module aan/uit                             |
| `package`              | `pkgs.nextcloud-client`                  | Levert `nextcloudcmd`                       |
| `credentialsFile`      | `~/.config/nextcloud-sync/credentials`   | EnvironmentFile met `NC_USER`/`NC_PASSWORD` |
| `syncs.<n>.serverUrl`  | —                                        | Basis-URL van de server                     |
| `syncs.<n>.localPath`  | —                                        | Lokale map (leidende `~/` wordt geëxpandeerd)|
| `syncs.<n>.remotePath` | `/`                                      | Remote map (`--path`)                       |
| `syncs.<n>.interval`   | `10min`                                  | `OnUnitActiveSec`                           |
| `syncs.<n>.excludeFile`| `null`                                   | Exclude-list (`--exclude`)                  |
| `syncs.<n>.trust`      | `false`                                  | `--trust` (self-signed)                     |
| `syncs.<n>.extraArgs`  | `[ ]`                                     | Extra `nextcloudcmd`-argumenten             |
