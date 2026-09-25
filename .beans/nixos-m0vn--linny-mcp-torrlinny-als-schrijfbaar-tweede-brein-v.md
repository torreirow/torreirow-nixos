---
# nixos-m0vn
title: 'linny-mcp: torrlinny als schrijfbaar tweede brein voor Claude'
status: todo
type: epic
created_at: 2026-09-25T07:43:25Z
updated_at: 2026-09-25T07:43:25Z
---

Thematische container. Het torrlinny-notitieboek (122 markdown-notities) ontsluiten aan Claude
Online en Mobile als **schrijfbaar** tweede brein, via `linny-mcp` (MCP-server) op malandro.

Vandaag is torrlinny alleen leesbaar voor mensen: Hugo bouwt er een statische site van op
`linny.toorren.net` achter Authelia. Deze epic zet daar een tweede, agent-gerichte ontsluiting
naast — lezen en schrijven — zonder de bestaande site aan te raken.

Model: `mipmip/mipnix` doet dit al (`modules/HOSTS/dapperehaan-server/linny-mcp.nix` +
`durer-server/secondbrain.nix`, OpenSpec-capability `linny-mcp-hosting`). Upstream is
`github:linden-project/linny-mcp-server` (v0.2.0), met een eigen NixOS-module en overlay.

## Besluiten (uit /opsx:explore, 2026-09-25)

### Twee gescheiden werkmappen — NIET de bestaande checkout hergebruiken
Dit is het belangrijkste besluit en het minst voor de hand liggend. De notities staan al op
malandro in `/var/lib/torrlinny/checkout`, maar `linny-web-build.service` doet daar elke ~3 min:

    git -C "$CHECKOUT" reset --hard "origin/main"
    git -C "$CHECKOUT" clean -fdx

Een notitie die de agent net heeft geschreven is een **untracked** bestand; `clean -fdx` wist die.
Is hij al lokaal gecommit maar nog niet gepusht, dan gooit `reset --hard` hem alsnog weg. Landt de
Hugo-build in dat venster, dan is de notitie stil verdwenen — zonder foutmelding, want vanuit de
build klopt alles. mipmip heeft dit probleem niet: bij hem is de MCP de enige consument van het
corpus. Hier zijn er twee, en één is by design destructief.

Dus: linny-mcp krijgt een **eigen clone** (bv. `/var/lib/linny-mcp/corpus`). De Hugo-checkout
blijft ongemoeid en mag destructief blijven — daar is de gedeelde `linny-web`-module op ontworpen,
en die module bedient ook andere notebooks. GitHub blijft het knooppunt voor alle drie de
deelnemers (lobos/NeoVim, de agent op malandro, de Hugo-build).

Gevolg: een agent-notitie is pas op `linny.toorren.net` zichtbaar na een rondje GitHub —
schrijven -> git-sync (30 s) -> push -> Hugo fetch (3 min) -> build, dus **binnen ~4 minuten**.
Akkoord bevonden.

### Schrijfgrens: quarantine AAN + token-scope `write:inbox` (optie A)
`quarantine` is geen map maar een frontmatter-term (`status: agent-draft`, uit
`internal/defense/quarantine.go`). Hij doet pas iets in combinatie met de scope:

    // write:* always allows; write:inbox allows only quarantined (agent-draft) docs.

Met `write:inbox` kan de agent **nieuwe** documenten maken en alleen zijn eigen nog-niet-
gepromoveerde drafts bijwerken. Bestaande, met de hand geschreven notities zijn voor hem
onaanraakbaar. Met `write:*` is `agent-draft` slechts een sticker die de agent zelf kan weghalen.

Waarom dit telt: upstream noemt dit `hostile-corpus-defenses` — *"The corpus is untrusted input
(prompt injection); these reduce blast radius."* De aanval is niet een eigenwijze agent maar een
notitie die de agent aanstuurt. Relevant hier, want er komen mogelijk meetrec-transcripten in het
notitieboek: tekst die anderen hebben uitgesproken, via spraakherkenning, ongefilterd.

Prijs: er is nog **geen promotie-tool** (upstream open question). Promoveren = met de hand de
regel `status: agent-draft` weghalen in NeoVim. Daarna kan de agent er nooit meer bij.

### Leesscope: `read:*`
Alle 122 notities, inclusief het klantmateriaal. Bewust: het abonnement is betaald en
contractueel wordt de data niet voor training gebruikt. Beperken op `read:taxonomy:customer:...`
zou precies het deel afsnijden waarvoor het bedoeld is. Consequentie: het **token is het enige
slot** — dus per client een eigen token, roteerbaar, en intrekbaar zonder de andere te raken.

### Publiek eindpunt `linny-mcp.toorren.net`, geen Authelia, geen VPN-only
Een custom connector op claude.ai wordt **server-side door Anthropic opgehaald**, niet door de
browser of de telefoon. Een endpoint dat alleen binnen wireguard bereikbaar is, is voor Claude
Online en Mobile dus onbereikbaar — ook al zit de telefoon zelf in de VPN. Omdat online+mobile een
harde eis is, volgt: publiek met bearer-auth. Dit is ook waarom mipmip's `durer` publiek staat
terwijl de server zelf op een privé-IP bindt.

Authelia kan er niet voor: dat is een redirect-gebaseerde browserflow, en een MCP-client stuurt
alleen `Authorization: Bearer`. Dus een **eigen vhost** die Authelia overslaat.

### Overige harde punten uit de upstream-broncode
- **Corpus buiten `/home`.** De upstream-unit zet `ProtectHome = true`; `/home` is leeg in de
  sandbox en `ReadWritePaths` prikt daar niet doorheen.
- **`serve` bouwt nooit een index**, alleen lezen. Zonder aparte indexer zien clients nul
  documenten, en notities die via git-sync binnenkomen worden nooit vindbaar. mipmip ontdekte dit
  pas na deployment (aparte change `add-linny-mcp-indexer`).
- **`restartTriggers` op het ciphertext-pad** van het tokens-secret. De server leest het
  tokenbestand eenmalig bij start en herlaadt nooit; hercoderen laat de unitdefinitie
  byte-identiek, dus een `switch` zou de oude scopes in geheugen houden.
- **Bind een privé-IP.** `internal/config/bind.go` accepteert RFC1918/loopback/CGNAT maar weigert
  publieke IP's en `0.0.0.0`.
- **De indexer normaliseert termen** (`strings.ReplaceAll(strings.ToLower(term), " ", "-")`), dus
  case-varianten vallen voor MCP samen. Het opschonen (story 1) is hygiëne voor de Hugo-zijbalk en
  voorspelbaarheid, geen blokkade voor de MCP.

## Repo's in scope
- `torreirow/torreirow-nixos` — module, vhost, secrets (het meeste werk).
- `torreirow/torrlinny` — alleen story 1: frontmatter normaliseren. **Andere git-repo.**

## Acceptatiecriteria
1. `https://linny-mcp.toorren.net/healthz` antwoordt zonder auth; `/mcp` weigert zonder geldig
   bearer-token.
2. Claude Online én Mobile kunnen via een custom connector de notities doorzoeken.
3. De server bindt een privé-IP, nooit `0.0.0.0` of een publiek adres; TLS termineert in nginx.
4. Een agent-`create_doc` landt met `status: agent-draft` en staat binnen ~1 min op GitHub.
5. Een poging van de agent om een bestaande, niet-gequarantainede notitie te wijzigen wordt
   **geweigerd** (bewijs dat `write:inbox` werkt).
6. Een notitie die elders bewerkt en gepusht is, is na de git-sync-pull doorzoekbaar via MCP
   (bewijs dat de indexer meeloopt).
7. `/var/lib/torrlinny/checkout` is ongewijzigd van rol; `linny.toorren.net` blijft werken en de
   Hugo-build heeft geen agent-notitie gewist.
8. Geen tokenliteral of privésleutel in `/nix/store` of in een Nix-optie.
9. torrlinny-frontmatter kent geen case-varianten meer en elke notitie heeft een `customer`.

## Open punten (bewust niet opgelost)
- **git-sync stopt stil bij een hard conflict.** mipmip heeft hier `ntfyTopicURL` voor uitgesteld
  (zijn bean `mipnix-2dyz`). Wij hebben `notify-signal` al in huis — overwegen, niet verplicht.
- **Hoe merk je dat de indexer achterloopt?** Geen signaal bedacht.
- **Verschijnen agent-drafts op `linny.toorren.net`?** `status` is nu ongebruikt in torrlinny, dus
  Hugo toont ze gewoon mee. Losse knop, later te beslissen.

## Ship
Eén OpenSpec change voor de nixos-kant (voorstel: `add-linny-mcp-hosting`). Story 1 valt buiten
OpenSpec (andere repo). Child-stories spiegelen de fases. `/cas:1shotepic` op deze epic.
