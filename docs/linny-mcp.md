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

De scope hangt af van de route. `write:inbox` begrenst tot eigen drafts; `write:*` geeft volledige
schrijfrechten en maakt de quarantaine-term tot niet meer dan een sticker die de agent zelf kan
weghalen:

| | `write:inbox` | `write:*` |
|-------------------------------------|---------------|-----------|
| nieuw document maken | ✓ krijgt `status: agent-draft` | ✓ krijgt `status: agent-draft` |
| eigen draft bijwerken | ✓ | ✓ |
| **jouw bestaande notitie wijzigen** | **✗ geweigerd** | ✓ |
| na promotie er weer bij | ✗ nooit meer | ✓ |

**Stand per 2026-10-01** (change `add-linny-mcp-public-write`): het tunnel-token `claude-web`
draagt `read:*,write:*` — Claude Code/Desktop mag dus ook bestaande notities wijzigen. De publieke
route blijft read-only tenzij de switch `publicWrite` aan staat (zie onder), en krijgt dan óók
`read:*,write:*`.

Upstream noemt de begrenzing `hostile-corpus-defenses`: *"The corpus is untrusted input (prompt
injection); these reduce blast radius."* De aanval is niet een eigenwijze agent maar een notitie
die de agent aanstuurt — relevant zodra er meetrec-transcripten in het notitieboek belanden. Met
`write:*` vervalt die bescherming bewust; vandaar dat de publieke schrijfroute default uit staat en
achter 2FA + `group:admins` zit.

**Promoveren doe je met de hand**: haal de regel `status: agent-draft` uit de frontmatter. Er is
(nog) geen promotie-tool; upstream houdt dat open. Met `write:inbox` kon de agent er daarna niet
meer bij; met `write:*` is promotie geen slot meer.

## De publieke schrijfschakelaar

`services.linny-mcp-host.publicWrite` (bool, default `false`) bepaalt of de **publieke** route mag
schrijven. De optie kiest welk agenix-snippet nginx in de `include` van `/mcp` zet:

| stand | snippet | intern token | publieke route |
|-------------|------------------------------------|---------------|----------------|
| `false` | `linny-mcp-nginx-token.age` | `read:*` | read-only |
| `true` | `linny-mcp-nginx-write-token.age` | `read:*,write:*` | read + write |

Omzetten is `nixos-rebuild switch --flake .#malandro` en volledig omkeerbaar: terug op `false` +
switch ontneemt de publieke route onmiddellijk alle schrijfrechten, zonder token-rotatie. Het
schrijf-secret wordt alléén gedecrypt zolang de schakelaar aan staat (`mkIf (oidc.enable &&
publicWrite)`), zodat lees- en schrijf-snippet nooit beide hetzelfde pad claimen.

De route zit bovendien achter de benoemde Authelia-policy `linny-mcp-write` (`modules/authelia.nix`):
`default_policy = deny`, met één regel `two_factor` voor `subject = group:admins`. Dat sluit het
oude open punt dat élke Authelia-gebruiker met 2FA een connector-token kreeg — nú moet je ook in
`admins` zitten. De policy staat er onvoorwaardelijk op, ook in de read-only-stand.

## Bestanden & paden

| Pad | Rol |
|-------------------------------------|------------------------------------------------|
| `modules/linny-mcp.nix` | Wrapper: secrets, corpus, git-sync, indexer, validator, vhost |
| `modules/linny-mcp-authz/` | Tokenvalidator + tests + `verify-live.sh` |
| `home/module/linny-mcp-tunnel/` | Ssh-tunnel als home-manager user-service (lobos) |
| `secrets/linny-mcp-deploy-key.age` | **Read/write** deploy key voor torrlinny |
| `secrets/linny-mcp-tokens.age` | Gehashte bearer-records (JSON-lines) |
| `secrets/linny-mcp-nginx-token.age` | Nginx-snippet met het interne leestoken (`read:*`) |
| `secrets/linny-mcp-nginx-write-token.age` | Nginx-snippet met het interne schrijftoken (`read:*,write:*`); alleen gebruikt bij `publicWrite = true` |
| `secrets/linny-mcp-authz-secret.age` | Client secret van de validator bij Authelia |
| `/var/lib/linny-mcp/corpus` | Git-werkmap die de agent beschrijft |
| `/var/lib/linny-mcp/state` | Wegwerp-index (SQLite + JSON) |
| `/var/lib/linny-mcp/known_hosts` | Buiten de working tree, anders synct git-sync 'm mee |

Poort 8096 (linny-mcp) en 8097 (de validator), beide op `127.0.0.1`. De server weigert publieke
adressen en `0.0.0.0`; TLS termineert in de nginx op dezelfde host.

## Twee routes naar binnen

Er zijn twee wegen naar dezelfde server, met een verschillend slot en verschillende rechten.

```
                                     malandro
lobos                                ┌──────────────────────────────┐
  Claude Code ──┐                    │                              │
                ├─► 127.0.0.1:8096 ══╪═ssh═► 127.0.0.1:8096 ────────┼─► linny-mcp
  Claude Desktop┘                    │            ▲                 │   (read + write)
        linny-mcp-tunnel.service     │            │                 │
                                     │       nginx:443 ─────────────┼─► leestoken
telefoon / claude.ai                 │            │ auth_request    │
  Claude Mobile ─────────────────────┼─────►      ▼                 │
  Claude Online                      │       linny-mcp-authz :8097  │
                                     │            │ introspection   │
                                     │            ▼                 │
                                     │       Authelia :9091         │
                                     └──────────────────────────────┘
```

| | tunnel | publieke route |
|------------|---------------------------|-----------------------------------------|
| slot | ssh-toegang tot malandro | Authelia-inlog met 2FA + `group:admins` |
| token | `read:*`, `write:*` | `read:*`, of `read:*,write:*` als de switch aan staat |
| schrijven | ja, volledig | alleen als `publicWrite = true` |
| clients | Claude Code, Desktop | Claude Mobile, Online |

De tunnel presenteert het `claude-web`-token rechtstreeks en is dus altijd schrijfbaar. De
publieke route is standaard read-only doordat nginx het clienttoken **omwisselt** voor een vast
intern token — van oudsher een leestoken (`read:*`). Dat is geen netwerk-eigenschap maar een
nginx-token-swap, en precies daarom schakelbaar (zie onder).

### De tunnel

Een home-manager user-service, `home/module/linny-mcp-tunnel`. Twee dingen daarin zijn geen detail:

- **`SSH_AUTH_SOCK` moet expliciet.** De systemd-user-manager erft je shell-omgeving niet en zet
  zelf `%t/gcr/ssh` (gnome-keyring). Die agent kent de malandro-sleutel niet en meldt
  `agent refused operation` — misleidend, want er ís een agent, alleen de verkeerde. De sleutel
  komt uit rbw: `%t/rbw/ssh-agent-socket`.
- **`ExitOnForwardFailure=yes`.** Zonder dit blijft ssh draaien terwijl de forward mislukte, en lijkt
  de unit gezond terwijl geen enkele client verbinding maakt.

### De publieke route: Authelia als OIDC-provider, niet als forward-auth

Een custom connector op claude.ai wordt **server-side door Anthropic opgehaald**, niet door je
browser of je telefoon. Een endpoint binnen wireguard is voor Claude Mobile dus onbereikbaar, ook
al zit je telefoon zelf in de VPN. Vandaar publiek.

Het `autheliaAuthConfig`-patroon van `linny.toorren.net` kan hier niet: dat is een redirect naar een
inlogpagina, en een MCP-client volgt geen redirect naar HTML. **Maar Authelia kan twee dingen**, en
alleen de eerste was hier ongeschikt:

```
forward-auth (linny.toorren.net)       OIDC-provider (linny-mcp.toorren.net)
────────────────────────────────       ─────────────────────────────────────
onauthenticated → 302 naar portaal     client haalt zelf een access token
alleen bruikbaar in een browser        client stuurt Bearer authelia_at_…
```

`nginx` doet `auth_request` naar **`linny-mcp-authz`** en wisselt daarna de `Authorization`-header
om voor het interne leestoken. Die tussenstap is nodig omdat `auth_request` alleen op een
statuscode kan beslissen, terwijl Authelia's introspection-endpoint met **200 en
`{"active": false}`** antwoordt voor een ongeldig token — de body moet dus gelezen worden.

Waarom niet Authelia's eigen authz-endpoint, dat bearer-tokens aankan: dat accepteert alleen tokens
met de scope `authelia.bearer.authz`, en bij die scope eist Authelia **verplicht PAR**. Claude doet
geen PAR. Gemeten op 2026-09-25, ook niet nadat de discovery-metadata het als verplicht adverteerde
— en Wallos brak daar wél op, want die vlag geldt server-breed.

### Wat de flow onderweg nodig had

Vier dingen die je niet kunt beredeneren, alleen meten. Alle vier kwamen uit het
`nginx-access.log`, dat de volledige query-parameters van de authorization request bewaart:

| symptoom | oorzaak |
|---------------------------------------|------------------------------------------------|
| PAR-fout | scope `authelia.bearer.authz` laten vallen |
| `redirect_uri` komt niet overeen | echte waarde is `https://claude.ai/api/mcp/auth_callback`, niet wat de documentatie suggereert |
| audience niet whitelisted | Claude stuurt `resource=` (RFC 8707) → `audience` op de client |
| introspection weigert de validator | Authelia legt per client één methode vast; hier `client_secret_basic` |

En één die je pas ziet als je loopback gebruikt: Authelia leidt zijn *effective issuer* uit het
verzoek af en weigert met `invalid X-Forwarded-Proto header value 'http'`. De validator doet zich
daarom voor als de reverse proxy — `Host`, `X-Forwarded-Proto` en `X-Forwarded-Host`.

### Drie klokken, en welke waarvan is

Het meest merkbare gedrag van de koppeling is hoe vaak je opnieuw moet inloggen. Daar zitten drie
onafhankelijke timers achter, en ze horen bij verschillende dingen:

| klok | waarde | beschermt | merkbaar als |
|-----------------|--------|--------------------------------|------------------------------|
| sessie-cookie | 5m / 1u | een openstaande browser | inlogscherm mét tweede factor |
| access-token | 1u | het verzoek onderweg | niets — wordt stil ververst |
| refresh-token | 30d | de koppeling zelf | toestemmingsscherm |

**De refresh-token is een maximale stilteperiode, geen sessieduur.** Authelia roteert hem: bij elke
verversing komt er een nieuwe met een nieuwe klok. Gebruik je de connector dagelijks, dan schuift
die mee en zie je nooit iets. Alleen na een maand niets doen moet je opnieuw koppelen.

Met Authelia's standaard van **90 minuten** was dat anders: gemeten op 2026-09-29 vroeg de connector
vijf keer op één dag om opnieuw te autoriseren, tegen `wallos` eens per twee weken. In redis stonden
1766 sessiesleutels, allemaal met minder dan een uur te gaan — de vingerafdruk van voortdurend
opnieuw inloggen.

**De access-token is bewust níét verlengd.** Dat is de enige credential die bij elk verzoek over de
lijn gaat; die oprekken vergroot het venster waarin een onderschepte token bruikbaar is, en levert
niets op — je merkt een verlopen access-token niet.

**De sessie-cookie blijft met opzet op de standaard.** Die beschermt een openstaande browser, en
staat los van de koppeling. Het globaal oprekken zou álle vhosts raken om een probleem bij de
connector op te lossen. Vind je de vijf minuten te krap, gebruik dan het **"onthoud mij"-vinkje**
bij het inloggen — dat is per keer en zelfgekozen, en Authelia's standaard daarvoor is een maand.
Let op: dat vinkje staat op het *inlogformulier*, niet op het toestemmingsscherm.

Toestemming wordt onthouden (`consent_mode: pre-configured`, een maand). Dat is geen verzwakking:
zo'n toestemming vervalt zodra subject, client, scopes of audience afwijken van wat eerder is
toegestaan. Vier identieke schermen per dag leidt er juist toe dat je stopt met lezen wat je
goedkeurt — en dan valt een échte wijziging in de gevraagde rechten niet meer op.

### Waarom een IP-filter géén alternatief was

Een eerdere poging was `allow 192.168.2.0/24` op de vhost. Dat kan in deze opstelling principieel
niet werken: `linny-mcp.toorren.net` wijst naar het publieke adres, dus ook verkeer uit het eigen
netwerk gaat naar buiten en komt via de router terug — nginx ziet het WAN-adres. Gemeten:

```
82.172.137.171  "GET /healthz"  403   ← lobos
82.170.93.180   "GET /healthz"  403   ← malandro zelf
```

Lobos komt met wéér een ander adres binnen doordat een policy-route (tabel 51820) verkeer naar dat
publieke adres door de `tn_arkana`-tunnel stuurt. Er bestaat hier geen bronadres dat "LAN" betekent.
Split-horizon DNS zou het oplossen, maar de resolver is de router (192.168.2.254), niet de Pi-hole.

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

### Drie soorten geheimen, met verschillende levens

| Geheim | Waar het heen gaat | Wanneer roteren |
|---------------------------------|--------------------------------|------------------------|
| `linny-mcp-tokens.age` | Vaultwarden + tunnel-clients | bij verlies of vertrek |
| `linny-mcp-nginx-token.age` | nergens; nginx ↔ linny-mcp | vrij, genereer opnieuw |
| `linny-mcp-nginx-write-token.age` | nergens; nginx ↔ linny-mcp (schrijf) | vrij, genereer opnieuw |
| `linny-mcp-authz-secret.age` | nergens; validator ↔ Authelia | idem |

De onderste twee gaan **nooit naar een client**. Ze hoeven dus niet in Vaultwarden, en roteren is
een kwestie van opnieuw genereren en uitrollen — er is niemand die ze opnieuw moet invullen.

**Het clientgeheim van de validator is bewust goedkoop gehasht** (`m=8192,t=1,p=1` in plaats van
Authelia's standaard `m=65536,t=3,p=4`). Gemeten op malandro: met de standaard kostte élke
introspection **164 ms, waarvan 163 ms die hash** — een verzoek zónder client-auth deed er 1 ms
over. Nu 29 ms. Die rekenkosten bestaan om zwakke, door mensen gekozen wachtwoorden te beschermen
tegen offline kraken; dit geheim is 72 willekeurige tekens, en daar voegt een dure hash niets aan
toe. Zonder die correctie zou de cache in de validator lang moeten zijn, en precies die cachetijd
is het venster waarin een ingetrokken token nog werkt.

Hergenereer het geheim en de hash samen — ze horen bij elkaar:

```bash
# op malandro: nieuw geheim + hash
authelia crypto rand --length 72 --charset alphanumeric
authelia crypto hash generate argon2 -m 8192 -i 1 -p 1 --password '<geheim>'
# op lobos: platte geheim versleutelen, hash in modules/authelia.nix
cd secrets && ragenx -e linny-mcp-authz-secret.age
```

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
python3 modules/linny-mcp_test.py                       # config, zonder deploy
python3 modules/linny-mcp-authz/linny_mcp_authz_test.py # validator, zonder netwerk
ssh malandro 'bash modules/linny-mcp-authz/verify-live.sh'   # live, op de host
```

De eerste toetst de opgebouwde malandro-config: bind-adres, de scheiding van de Hugo-werkmap,
quarantine, de agenix-paden, de restartTriggers, de ordening van de units, en dat er géén
tokenliteral in de nginx-config staat. Hij evalueert de configuratie **twee keer** — met en zonder
de OIDC-laag — omdat `//` in Nix een ondiepe merge is en een fout daarin alleen zichtbaar is als de
laag aanstaat.

`verify-live.sh` toont aan dat het publieke endpoint zonder Authelia-inlog niets prijsgeeft. De
scherpste controle is niet dat onzin geweigerd wordt, maar dat een **echt, door Authelia als
`active` bevestigd token van een andere client** ook 401 krijgt. Zonder die `client_id`-controle in
de validator zou elk geldig token op deze Authelia het notitieboek openen — ook dat van Wallos.

## Open punten

- **git-sync stopt stil bij een hard conflict.** Er is nog geen melding. `notify-signal` bestaat al
  in deze repo en is de voor de hand liggende opvolging.
- **Geen signaal als de indexer achterloopt.**
- **Een ingetrokken token blijft tot 5 seconden bruikbaar.** De validator cachet een geldig bevonden
  token op de sha256 ervan (`oidc.cacheTtl`). Zonder cache kost elke aanroep een introspection van
  ~29 ms. Dat was ooit 164 ms; zie "Tokens roteren".
- **Het slot is een Authelia-account mét 2FA, niet groepslidmaatschap.** Er zijn geen custom
  `authorization_policies`, dus de `group:admins`-regel uit `access_control` geldt niet voor de
  OIDC-flow. Elke Authelia-gebruiker die 2FA doorloopt krijgt een token.
- **Agent-drafts verschijnen gewoon op `linny.toorren.net`** — `status` is verder ongebruikt in
  torrlinny, dus Hugo toont ze mee. Filteren kan, is nog niet besloten.
