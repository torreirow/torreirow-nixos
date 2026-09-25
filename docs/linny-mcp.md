# linny-mcp — torrlinny als schrijfbaar tweede brein

Ontsluit hetzelfde notitieboek als `linny.toorren.net`, maar dan voor **agents**: lezen én
schrijven via MCP op **https://linny-mcp.toorren.net**, voor Claude Online en Mobile.

> Module: `modules/linny-mcp.nix`, ingeschakeld met `services.linny-mcp-host.enable = true` in
> `hosts/malandro/configuration.nix`. Wrapper rond de upstream `services.linny-mcp`
> (flake-input `linny-mcp` → `github:linden-project/linny-mcp-server`).

## Twee werkmappen, en waarom dat moet

```
                    GitHub: torreirow/torrlinny
                    ▲       ▲                │
        push (RW)   │       │ push (jij)     │ fetch (RO)
                    │       │                ▼
   ┌────────────────┴───┐   │   ┌────────────────────────────┐
   │ malandro           │   │   │ malandro                   │
   │ /var/lib/linny-mcp │   │   │ /var/lib/torrlinny/checkout│
   │   /corpus          │   │   │                            │
   │                    │   │   │  reset --hard + clean -fdx │
   │ linny-mcp (rw)     │   │   │  ← wegwerp, mág destructief│
   │ git-sync   30 s    │   │   │  linny-web-build   3 min   │
   │ lindexer build+watch│  │   │       ▼                    │
   └────────────────────┘   │   │  live/ → nginx + Authelia  │
                            │   └────────────────────────────┘
                     ┌──────┴──────┐
                     │ lobos       │
                     │ NeoVim Linny│
                     └─────────────┘
```

**Deel deze twee mappen nooit.** `linny-web-build.service` doet elke ~3 minuten:

```bash
git -C "$CHECKOUT" reset --hard "origin/main"
git -C "$CHECKOUT" clean -fdx
```

Een notitie die de agent net heeft geschreven is een **untracked** bestand; `clean -fdx` wist die.
Is hij lokaal gecommit maar nog niet gepusht, dan gooit `reset --hard` hem alsnog weg. Landt de
Hugo-build in dat venster, dan is de notitie stil verdwenen — zonder foutmelding, want vanuit de
build klopt alles.

**Gevolg:** een agent-notitie staat pas op `linny.toorren.net` na een rondje GitHub — schrijven →
git-sync (30 s) → push → Hugo fetch (3 min) → build, dus binnen ~4 minuten. Dat is bewust zo.

## Wat de agent wel en niet mag

`quarantine = true` zet agent-documenten in de frontmatter-term `status: agent-draft` — een term,
geen map. Dat doet pas iets samen met de **tokenscope**:

```go
// write:* always allows; write:inbox allows only quarantined (agent-draft) docs.
```

De tokens dragen `read:*,write:inbox`. Daarmee:

| | |
|---|---|
| nieuw document maken | ✓ krijgt `status: agent-draft` |
| eigen draft bijwerken | ✓ zolang de term erop staat |
| **jouw bestaande notitie wijzigen** | **✗ geweigerd** |
| na promotie er weer bij | ✗ nooit meer |

Upstream noemt dit `hostile-corpus-defenses`: *"The corpus is untrusted input (prompt injection);
these reduce blast radius."* De aanval is niet een eigenwijze agent maar een notitie die de agent
aanstuurt — relevant zodra er meetrec-transcripten in het notitieboek belanden.

**Promoveren doe je met de hand**: haal de regel `status: agent-draft` uit de frontmatter. Er is
(nog) geen promotie-tool; upstream houdt dat open. Daarna kan de agent er niet meer bij.

## Bestanden & paden

| Pad | Rol |
|-------------------------------------|------------------------------------------------|
| `modules/linny-mcp.nix` | Wrapper: secrets, corpus, git-sync, indexer, vhost |
| `secrets/linny-mcp-deploy-key.age` | **Read/write** deploy key voor torrlinny |
| `secrets/linny-mcp-tokens.age` | Gehashte bearer-records (JSON-lines) |
| `/var/lib/linny-mcp/corpus` | Git-werkmap die de agent beschrijft |
| `/var/lib/linny-mcp/state` | Wegwerp-index (SQLite + JSON) |
| `/var/lib/linny-mcp/known_hosts` | Buiten de working tree, anders synct git-sync 'm mee |

Poort 8096, gebonden op `127.0.0.1`. De server weigert publieke adressen en `0.0.0.0`; TLS
termineert in de nginx op dezelfde host.

## Hoe je erbij komt: een ssh-tunnel, geen publieke vhost

De publieke vhost staat **uit** (`services.linny-mcp-host.publicEndpoint = false`). Hij bestond
alleen voor custom connectors op claude.ai — en die mogen in de organisatie niet door gebruikers
worden aangemaakt, alleen door een admin. Zolang dat zo is bestaat de enige reden voor een publiek
endpoint niet, en zijn alle clients lokaal.

```
lobos                                    malandro

Claude Code ──┐
              ├─► 127.0.0.1:8096 ══ssh══► 127.0.0.1:8096 ──► linny-mcp
Claude Desktop┘
              linny-mcp-tunnel.service              (geen nginx, geen TLS nodig)
```

De tunnel is een home-manager user-service, `home/module/linny-mcp-tunnel`. Twee dingen daarin zijn
geen detail:

- **`SSH_AUTH_SOCK` moet expliciet.** De systemd-user-manager erft je shell-omgeving niet en zet
  zelf `%t/gcr/ssh` (gnome-keyring). Die agent kent de malandro-sleutel niet en meldt
  `agent refused operation` — misleidend, want er ís een agent, alleen de verkeerde. De sleutel
  komt uit rbw: `%t/rbw/ssh-agent-socket`.
- **`ExitOnForwardFailure=yes`.** Zonder dit blijft ssh draaien terwijl de forward mislukte, en lijkt
  de unit gezond terwijl geen enkele client verbinding maakt.

Toegangsbewijs is dus ssh-toegang tot malandro, plus het bearer-token.

### Waarom een IP-filter géén alternatief was

De eerste poging was `allow 192.168.2.0/24` op de vhost. Dat kan in deze opstelling principieel niet
werken: `linny-mcp.toorren.net` wijst naar het publieke adres, dus ook verkeer uit het eigen netwerk
gaat naar buiten en komt via de router terug — nginx ziet het WAN-adres. Gemeten:

```
82.172.137.171  "GET /healthz"  403   ← lobos
82.170.93.180   "GET /healthz"  403   ← malandro zelf
```

Lobos komt met wéér een ander adres binnen doordat een policy-route (tabel 51820) verkeer naar dat
publieke adres door de `tn_arkana`-tunnel stuurt. Er bestaat hier geen bronadres dat "LAN" betekent.
Split-horizon DNS zou het oplossen, maar de resolver is de router (192.168.2.254), niet de Pi-hole.

## Waarom er geen Authelia voor zit

Een custom connector op claude.ai wordt **server-side door Anthropic opgehaald**, niet door je
browser of je telefoon. Een endpoint dat alleen binnen wireguard bereikbaar is, is voor Claude
Online en Mobile dus onbereikbaar — ook al zit je telefoon zelf in de VPN. Vandaar publiek.

En Authelia is een redirect-gebaseerde browserflow; een MCP-client stuurt alleen
`Authorization: Bearer` en volgt geen redirect. Deze vhost gebruikt daarom bewust **niet** het
`autheliaAuthConfig`-patroon van `linny.toorren.net`. Het slot is het bearer-token.

## De Host-header moet loopback blijven

De MCP-SDK zet DNS-rebinding-bescherming **automatisch** aan zodra de server op een loopback-adres
luistert, en weigert dan elke `Host` die geen loopback-naam is:

```go
// go-sdk/mcp/streamable.go
if util.IsLoopback(localAddr.String()) && !util.IsLoopback(req.Host) {
    http.Error(w, "Forbidden: invalid Host header", 403)
}
```

Met nginx' aanbevolen proxy-headers (`proxy_set_header Host $host;`) komt daar
`linny-mcp.toorren.net` binnen en antwoordt de server **403 op elke `/mcp`-call, óók met een geldig
token**. Het symptoom lijkt op een tokenprobleem maar is het niet: `/healthz` blijft gewoon 200.

Daarom staat `recommendedProxySettings = false` op deze location en zetten we de headers zelf, met
`Host localhost`. Twee keer `proxy_set_header Host` is géén optie — nginx stuurt ze dan allebei en
Go antwoordt met 400. `req.Host` wordt in de SDK nergens anders gebruikt dan in die ene check, dus
het overschrijven kost geen functionaliteit; `publicHostname` in de serverconfig staat los daarvan
en dient alleen de logregel.

## Twee sleutels op één repo

```
torrlinny-deploy-malandro   read_only=true    ← linny-web-build (Hugo)
linny-mcp-malandro (rw)     read_only=false   ← git-sync van linny-mcp
```

De read-only sleutel blijft read-only: die hoort bij het proces dat zijn werkmap leegveegt, en dat
mag nooit kunnen pushen.

## De indexer is niet optioneel

`linny-mcp serve` **leest** alleen een index en bouwt er nooit een; bovendien herindexeert het
alleen zijn *eigen* schrijfacties. Zonder `linny-mcp-index.service` zien clients nul documenten, en
worden notities die via git-sync binnenkomen nooit vindbaar.

```
ExecStartPre = lindexer build ...   # klaar vóór de unit "gestart" heet
ExecStart    = lindexer watch ...   # fsnotify, debounced
```

`linny-mcp.service` is erná geordend en ziet dus altijd een gevulde index.

## Tokens roteren

```bash
nix run github:linden-project/linny-mcp-server -- gen-token --name claude-web --scopes 'read:*,write:inbox'
```

Levert een one-time token (naar Vaultwarden en de Claude-connector) en een gehasht record. Records
staan als JSON-lines in `secrets/linny-mcp-tokens.age`; lege regels en `#`-commentaar worden
overgeslagen.

**Secrets schrijven gaat via stdin**, niet via `$EDITOR`:

```bash
cd secrets && ragenx -e linny-mcp-tokens.age < records.jsonl
```

Agenix overschrijft je `$EDITOR` met `cp -- /dev/stdin` zodra stdin niet interactief is (0.15.0,
regel 167). Een zelfgekozen editor levert dan stil een **lege payload** op — een geldig ogend
`.age`-bestand zonder inhoud, exit 0, geen waarschuwing.

Na hercodering pikt de `restartTrigger` op het ciphertext-pad de wijziging op: de server leest het
tokenbestand namelijk eenmalig bij start en herlaadt nooit.

## Commando's

```bash
sudo systemctl status linny-mcp linny-mcp-index linny-mcp-git-sync
sudo systemctl start linny-mcp-git-sync      # nu synchroniseren
journalctl -u linny-mcp -n 50
curl -s https://linny-mcp.toorren.net/healthz          # 200, zonder auth
curl -s -o /dev/null -w '%{http_code}\n' https://linny-mcp.toorren.net/mcp   # zonder token: geweigerd
sudo -u linny-mcp git -C /var/lib/linny-mcp/corpus status
```

## Testen

```bash
python3 modules/linny-mcp_test.py
```

Toetst de opgebouwde malandro-config zonder te deployen: bind-adres, de scheiding van de
Hugo-werkmap, quarantine, het agenix-pad, de restartTrigger, de ordening van de units en dat er
géén Authelia op de vhost zit.

## Open punten

- **git-sync stopt stil bij een hard conflict.** Er is nog geen melding. `notify-signal` bestaat al
  in deze repo en is de voor de hand liggende opvolging.
- **Geen signaal als de indexer achterloopt.**
- **Agent-drafts verschijnen gewoon op `linny.toorren.net`** — `status` is verder ongebruikt in
  torrlinny, dus Hugo toont ze mee. Filteren kan, is nog niet besloten.
