# AI-crawler-blokkade (malandro)

Module: `modules/ai-blocklist/` (`default.nix` + `update-ai-blocklist.py`), sites in
`hosts/malandro/configuration.nix` onder `services.aiBlocklist.sites`. Sinds 2026-11-02.

## Wat het doet

- `ai-blocklist.service` (oneshot, dagelijks via `ai-blocklist.timer`, ook bij boot) haalt
  `ai-robots-txt/ai.robots.txt` `robots.json` op en schrijft naar `/var/lib/ai-blocklist/`:
  - `ai-bots-map.conf` — `map $http_user_agent $ai_bot`, geïncludeerd in `commonHttpConfig`
  - `robots/<vhost>.txt` — de **bestaande** `robots.txt` uit de webroot, aangevuld met een
    Disallow-groep voor elke AI-bot die er nog niet in staat
  - `robots.json` — cache van de laatst geslaagde lijst
- Per site: `location = /robots.txt` (alias naar het gegenereerde bestand, ook bereikbaar voor
  AI-bots) en `if ($ai_bot) { return 403; }` in `/` en de `extraLocations`.
- Per site `allowAgents = [ ... ]`: die bots krijgen op díe site geen 403 en geen Disallow in
  `robots.txt`. De module zet daarvoor in `commonHttpConfig` een afgeleide map
  `$ai_bot_<vhost>` (`default $ai_bot;` + de vrijgegeven namen → `0`) en de site toetst die
  variabele. Sites zonder `allowAgents` gebruiken gewoon `$ai_bot`. Een naam die niet in de
  botlijst staat geeft een waarschuwing in het journal.
- `ai-blocklist.path` draait de service opnieuw zodra een `robots.txt` in een webroot wordt
  herschreven (release.sh). `touch` alleen triggert niet (`PathChanged` = close-after-write).

## Sites

| vhost                    | sitemap | noindex | extra                               |
| ------------------------ | ------- | ------- | ----------------------------------- |
| toorren.net              | ja      | nee     | `~ \.php$`                          |
| wereldvanbegrip.nl       | ja      | nee     |                                     |
| cckafe.com               | nee     | nee     | `allowAgents`: facebookexternalhit  |
| boaz.toorren.net         | nee     | **ja**  | `X-Robots-Tag: noindex, nofollow`   |
| cv-jolijn.toorren.net    | nee     | **ja**  | `X-Robots-Tag: noindex, nofollow`   |
| grainwork.dutchyland.net | nee     | nee     | publieke paden (`/welkom/`, assets) |

Bewust niet: alles achter Authelia (wouter), de catch-all `_`, mailer, nxc.

## Valkuilen

- **Open `User-agent: *`-groep.** toorren.net had alleen `User-agent: *` zonder regel. Direct
  daarachter `User-agent: GPTBot` + `Disallow: /` maakt er één groep van → Google ook geblokkeerd.
  Het script sluit zo'n groep af met `Allow: /`.
- **Geen extra `User-agent: *` als die al bestaat** — Google voegt dubbele groepen samen en
  `Allow: /` wint dan van `Disallow: /` (zou cv-jolijn openzetten).
- **Hoofdletterduplicaten in de bronlijst** (`Webzio-Extended`/`webzio-extended`): ontdubbelen op
  kleine letters met vaste sortering, anders verschilt de uitvoer per run (hash-randomisatie) en
  herlaadt nginx elke dag.
- `facebookexternalhit` staat in de bronlijst → link-previews op Facebook/Messenger/Instagram
  krijgen 403. Per site vrijgeven met `allowAgents` (zo gedaan voor cckafe.com), **niet** via
  `ALLOWLIST` in het script: die geldt voor alle sites. `meta-externalagent`/`FacebookBot`
  blijven geblokkeerd. Facebook cachet een eerdere 403: na de switch in de
  [Sharing Debugger](https://developers.facebook.com/tools/debug/) "Scrape Again" doen.
- Gebruikersagenten met generieke namen in de lijst (`Code`, `Dot`, `Spider`, `Cursor`) matchen
  met `\b…\b`; gewone browsers raken ze niet (getest met Firefox/Chrome).

## Commando's

```bash
sudo systemctl start ai-blocklist.service
journalctl -u ai-blocklist.service -n 20
systemctl list-timers ai-blocklist.timer
curl -s -o /dev/null -w '%{http_code}\n' -A 'GPTBot/1.2' https://toorren.net/   # 403
curl -s -A 'GPTBot/1.2' https://toorren.net/robots.txt | head                  # 200
# allowAgents (cckafe.com): na switch eerst de service draaien voor de nieuwe robots.txt
curl -s -o /dev/null -w '%{http_code}\n' -A 'facebookexternalhit/1.1' https://cckafe.com/  # 200
curl -s -o /dev/null -w '%{http_code}\n' -A 'facebookexternalhit/1.1' https://toorren.net/ # 403
curl -s https://cckafe.com/robots.txt | grep -i facebookexternalhit             # niets
```

## Terugdraaien

`../../modules/ai-blocklist` en het `services.aiBlocklist.sites`-blok uit
`hosts/malandro/configuration.nix` halen, `nixos-rebuild switch`, daarna
`sudo rm -rf /var/lib/ai-blocklist`. De robots.txt-bestanden in de webroots zijn nooit aangeraakt.
