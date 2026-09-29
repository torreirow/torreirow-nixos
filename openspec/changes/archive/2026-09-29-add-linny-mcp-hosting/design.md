## Context

`linny-mcp` (upstream `linden-project/linny-mcp-server`, v0.2.0) levert een NixOS-module en een
overlay. Uit de broncode geverifieerd, want het bepaalt de vorm van deze change:

- De unit zet `ProtectSystem = "strict"`, `ProtectHome = true` en
  `ReadWritePaths = corpusPaths ++ stateDirs`. Een corpus onder `/home` is dus onzichtbaar in de
  sandbox; beide paden moeten bestaan vóór start, anders faalt de namespace-setup (226/NAMESPACE)
  nog voor exec.
- De service draait als een echte `linny-mcp` systeemgebruiker (geen DynamicUser). Alles wat
  dezelfde working tree aanraakt moet als die gebruiker draaien.
- `internal/config/bind.go` accepteert loopback en RFC1918 en weigert publieke adressen en
  `0.0.0.0`. nginx draait op dezelfde host, dus `127.0.0.1` volstaat (mipmip bindt een mesh-IP
  omdat zijn proxy op een ándere host staat).
- Auth is statische bearer-tokens; de module neemt alleen een **pad**.
- De server bezit nooit git. Een extern proces houdt het corpus synchroon.
- `linny-mcp serve` **leest** alleen een index; `lindexer` bouwt hem.

De rest hebben we al: nginx met ACME op malandro (wildcard `*.toorren.net`), agenix, en een
draaiende Hugo-build van hetzelfde notitieboek.

## Goals / Non-Goals

**Goals:**
- torrlinny schrijfbaar serveren aan Claude Online + Mobile over HTTPS.
- De bestaande Hugo-site en zijn checkout volledig ongemoeid laten.
- Agent-writes begrenzen tot documenten die de agent zelf heeft gemaakt.
- Bestaande patronen hergebruiken (nginx-vhost, agenix, module-wrapper zoals `torrlinny.nix`).

**Non-Goals:**
- ntfy/degraded-mode-alerting (upstream-optie blijft `null`).
- Multi-notebook hosting (één notebook).
- Wijzigen van het corpusformaat, de indexer of upstream-gedrag.
- Automatiseren van het DNS-record, de GitHub deploy-key-registratie of de Claude-clientconfig —
  dat is eenmalig handwerk, buiten deze change gedaan.

## Decisions

### Decision: een eigen corpus-clone, NIET `/var/lib/torrlinny/checkout`
Dit is de kern. De notities staan al op malandro, maar die checkout is van `linny-web-build`, dat
er elke ~3 minuten dit op loslaat:

    git -C "$CHECKOUT" reset --hard "origin/main"
    git -C "$CHECKOUT" clean -fdx

Een notitie die de agent net heeft geschreven is een **untracked** bestand; `clean -fdx` wist die.
Is hij lokaal gecommit maar nog niet gepusht, dan gooit `reset --hard` hem alsnog weg. Landt de
Hugo-build in dat venster, dan verdwijnt de notitie zonder foutmelding — vanuit de build klopt alles.

`linny-mcp` krijgt daarom `/var/lib/linny-mcp/corpus`. GitHub blijft het knooppunt voor alle drie de
deelnemers (lobos/NeoVim, de agent, de Hugo-build).
_Alternatief verworpen:_ de Hugo-build niet-destructief maken — dat verandert de gedeelde
`linny-web`-module, die ook andere notebooks bedient, voor een probleem dat alleen hier speelt.

_Gevolg:_ een agent-notitie is pas op `linny.toorren.net` zichtbaar na een rondje GitHub
(schrijven → git-sync 30 s → push → Hugo fetch 3 min → build), dus binnen ~4 minuten. Akkoord bevonden.

### Decision: `127.0.0.1` binden, TLS in nginx op dezelfde host
Bind-safety accepteert loopback. Omdat nginx op malandro draait is een mesh- of LAN-adres onnodig
en zou het alleen het aanvalsoppervlak vergroten.

### Decision: schrijfbaar, quarantine aan, tokenscope `read:*,write:inbox`
`quarantine = true` zet agent-documenten in de term `status: agent-draft` (frontmatter, geen map).
Dat doet pas iets in combinatie met de scope:

    // write:* always allows; write:inbox allows only quarantined (agent-draft) docs.

Met `write:inbox` maakt de agent nieuwe documenten en werkt hij alleen zijn eigen nog-niet-
gepromoveerde drafts bij; bestaande, met de hand geschreven notities zijn onaanraakbaar. Met
`write:*` was `agent-draft` slechts een sticker die de agent zelf kan weghalen.

Upstream noemt dit `hostile-corpus-defenses`: *"The corpus is untrusted input (prompt injection);
these reduce blast radius."* Relevant hier, want er kunnen meetrec-transcripten in het notitieboek
belanden — tekst die anderen hebben uitgesproken, via spraakherkenning, ongefilterd.

_Prijs:_ er is nog geen promotie-tool (upstream open question). Promoveren = met de hand
`status: agent-draft` weghalen; daarna kan de agent er nooit meer bij.

### Decision: een tweede, read/write deploy key
`torrlinny-deploy-key` blijft read-only: die hoort bij `linny-web-build`, en een proces dat zijn
werkmap leegveegt mag nooit kunnen pushen. Per-repo deploy key, geen account-brede PAT.

### Decision: `lindexer build` + `watch` als aparte unit, geordend vóór `serve`
`serve` bouwt nooit een index en herindexeert alleen zijn *eigen* writes. Zonder deze unit zien
clients nul documenten, en blijven notities die via git-sync binnenkomen onvindbaar. `ExecStartPre`
is klaar voordat de unit als gestart geldt, dus `linny-mcp.service` (erna geordend) ziet een
gevulde index. De gegenereerde index gaat naar de wegwerp-stateDir, nooit in de git-tracked corpus.
_Bron:_ mipmip liep hier ná zijn deployment tegenaan (aparte change `add-linny-mcp-indexer`).

### Decision: `restartTriggers` op het ciphertext-pad van het tokens-secret
De server leest het tokenbestand eenmalig bij start en herlaadt nooit. Hercoderen laat de
unitdefinitie byte-identiek, dus een `switch` zou de oude scopes in geheugen houden.

### Decision: publieke vhost zonder Authelia
Een custom connector op claude.ai wordt **server-side door Anthropic opgehaald**, niet door de
browser of de telefoon. Een endpoint dat alleen binnen wireguard bereikbaar is, is voor Claude
Online en Mobile onbereikbaar — ook al zit de telefoon zelf in de VPN. Online+mobile is een harde
eis, dus publiek + bearer-auth.

Authelia kan er niet voor: dat is een redirect-gebaseerde browserflow. De vhost gebruikt dus
bewust niet het `autheliaAuthConfig`-patroon van `linny.toorren.net`.

SSE-veilig: MCP's streamable-HTTP mag niet gebufferd worden, heeft HTTP/1.1 nodig en een lange
read-timeout, anders stallen langlopende `/mcp`-streams.

## Risks / Trade-offs

- [Twee schrijvers (jij in NeoVim + de agent) op één repo] → quarantine isoleert agent-documenten;
  git-sync commit WIP en rebaset. Markdown merget meestal schoon.
- [git-sync stopt stil bij een hard conflict] → geaccepteerd voor nu; `notify-signal` bestaat al in
  deze repo en is de voor de hand liggende opvolging. Genoteerd als open punt.
- [Publiek eindpunt met alleen een bearer-token als slot] → token per client, roteerbaar en
  intrekbaar; gehasht opgeslagen; server bindt loopback; `/healthz` is de enige route zonder auth.
- [Geen signaal als de indexer achterloopt] → open punt.

## Migration Plan

1. Land config (flake-input, module, vhost, PORTS.md).
2. Out-of-band, reeds gedaan: DNS-record, RW deploy key op GitHub, `gen-token` → agenix.
3. `nix eval` / `nixos-rebuild dry-build` op malandro.
4. `nixos-rebuild switch` op malandro (door de gebruiker).
5. Verifiëren: `/healthz`, een geauthenticeerde handshake, een agent-write op GitHub, een
   GitHub-edit doorzoekbaar via MCP, en een geweigerde write op een bestaande notitie.
6. Connectors configureren in Claude Online + Mobile.

Rollback: `services.linny-mcp-host.enable = false` + vhost weg en opnieuw deployen. Het corpus en
zijn git-historie blijven intact.

## Open Questions

- Moeten agent-drafts op `linny.toorren.net` zichtbaar zijn? `status` is nu ongebruikt in
  torrlinny, dus Hugo toont ze gewoon mee. Losse knop, later te beslissen.
- git-sync-cadans: 30 s zoals mipmip, of rustiger?
