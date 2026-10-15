## Context

`magister_server.py` gebruikt de OAuth refresh-token flow van de mobiele Magister-app (`M6LOAPP`).
`token.json` bevat `refresh_token` (opaque, 43 tekens, roteert), `access_token` (JWT, 1 uur geldig)
en `access_expires`. Bij elke keep-alive-run (~30 min, 07:00–22:00) wordt het access-token zo nodig
ververst. In het JWT zit `auth_time`, het moment van de oorspronkelijke passkey-login, en die claim
blijft bij elke refresh gelijk.

## Goals / Non-Goals

**Goals:**
- Eerlijk tonen wat we weten: de leeftijd van de sessie en de laatste refresh.
- Dezelfde gegevens als metric beschikbaar maken voor Grafana.
- Een ontbrekend of onleesbaar token mag de sync nooit breken.

**Non-Goals:**
- Een verloopdatum voorspellen of afleiden. Magister geeft de levensduur van het refresh-token niet
  prijs.
- Een alert op de leeftijd van de sessie, zolang de grens onbekend is.
- De werkelijke levensduur leren uit `invalid_grant`-gebeurtenissen (optie C, later).

## Decisions

**`auth_time` lezen zonder handtekeningcontrole.** We decoderen alleen het payload-deel van het JWT
(base64url + json, stdlib). Verificatie zou de JWKS van Magister en een crypto-dependency vereisen.
Dat is hier zinloos, want de waarde wordt alleen getoond en stuurt geen beslissingen aan. Het token
komt bovendien rechtstreeks van Magisters token-endpoint over TLS.

**`last_refresh` als veld in `token.json`.** Het veld wordt in dezelfde atomaire write meegeschreven
als de geroteerde tokens, dus het kan nooit uit de pas lopen met de tokens. Bij oude bestanden
zonder het veld valt de code terug op de mtime van `token.json`. Die wordt in de praktijk alleen bij
een refresh herschreven, dus de benadering is goed. Alternatief overwogen: alleen de mtime
gebruiken. Dat is impliciet en kwetsbaar, want elke andere write zou de waarde verschuiven.

**Eén pure functie `session_status(tokens, token_mtime)`.** Die geeft een dict
`{auth_time, last_refresh}` met floats of `None`. De functie zelf doet geen I/O, zodat ze los te
testen is. Footer en heartbeat gebruiken allebei dezelfde bron.

**Onbekend is `None`, nooit een exceptie.** Een kapot JWT, een ontbrekend veld of een onleesbaar
bestand levert `None` op. De footer toont dan "onbekend" en de heartbeat laat die metric weg. Een
weggelaten metric is eerlijker dan een 0, die in Grafana als 1970 zou verschijnen.

**De heartbeat blijft één bestand.** `magister_heartbeat.prom` krijgt de nieuwe series erbij, met
HELP/TYPE en de bestaande atomaire rename. De bestaande metric `magister_sync_heartbeat_timestamp`
blijft ongewijzigd, zodat de staleness-alerts blijven werken.

## Risks / Trade-offs

- Magister zou `auth_time` kunnen weglaten of de betekenis veranderen. De footer zegt dan
  "onbekend" en de sync zelf merkt er niets van.
- `last_refresh` geeft de laatste geslaagde refresh weer, niet de laatste poging. Dat is precies wat
  telt voor het sliding idle-venster.
- Tokenwaarden mogen nooit in logs of HTML terechtkomen. Alleen de tijdstempels worden gebruikt.
