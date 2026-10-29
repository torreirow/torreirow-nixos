# File Drop (upload.toorren.net)

Uploadpagina waar anderen bestanden bij ons neerzetten, met verplichte naam en e-mail en een
Cap-captcha. Ze zien geen bestanden van anderen.

```
browser ── upload.toorren.net ── nginx ── filedrop (Go, :8102) ──┬─ cap.toorren.net/<key>/siteverify
                                                                ├─ nxc.toorren.net public WebDAV (share)
                                                                └─ signal-cli REST :8088 (melding)
```

| Onderdeel     | Waarde                                                   |
|---------------|----------------------------------------------------------|
| Pagina        | `https://upload.toorren.net`                             |
| Code          | `pkgs/filedrop/` (Go + `index.html`), `modules/filedrop.nix` |
| Nextcloud     | account `nxceghmedia`, map `eghuploads`, File Drop-share |
| Opslag        | submap per inzending: `JJJJ-MM-DD UU.MM - Naam (email)`  |
| Captcha       | Cap site-key "filedrop" (site-key in `modules/filedrop.nix`) |
| Geheimen      | `secrets/filedrop-env.age`: `CAP_SECRET`, `NEXTCLOUD_SHARE_TOKEN` |
| Melding       | Signal naar `SIGNAL_RECIPIENT` uit `signal-numbers.age`  |
| Limiet        | 2048 MB per inzending, 6 inzendingen/min per IP (burst 3) |

## Waarom zo

- Nextcloud kent geen captcha en geen verplicht e-mailveld op een publieke share. Een
  captcha-pagina met daarna een redirect is omzeilbaar zodra de link bekend is. Daarom zet de
  dienst de bestanden zelf door, en blijft het share-token geheim (alleen in agenix; de repo is
  publiek).
- Naam, e-mail en `cap-token` staan in het formulier vóór het bestandsveld. De dienst leest de
  multipart-stroom op volgorde en controleert alles voordat er één byte naar Nextcloud gaat.
- Bestanden worden gestreamd (chunked PUT), niet op malandro gebufferd.
- Honeypot-veld `website`: ingevuld → "Bedankt!" zonder opslag.

## Share-link of Cap-sleutel vervangen

```bash
cd secrets && ragenx -e filedrop-env.age   # CAP_SECRET=… / NEXTCLOUD_SHARE_TOKEN=…
sudo nixos-rebuild switch --flake .#malandro
```

Een nieuw share-token komt uit de link `https://nxc.toorren.net/s/<token>`. Controle dat het een
echte file drop is (geen leesrechten):

```bash
curl -s https://nxc.toorren.net/s/<token> | grep -o 'files_sharing-view" value="[^"]*' \
  | sed 's/.*value="//' | base64 -d   # moet "public-file-drop" geven
```

## Logs

```bash
journalctl -u filedrop -f    # "upload ok: N file(s) …" of de foutoorzaak
```
