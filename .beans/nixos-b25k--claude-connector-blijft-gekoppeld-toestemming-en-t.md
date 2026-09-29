---
# nixos-b25k
title: 'Claude-connector blijft gekoppeld: toestemming en tokenlevensduur afstemmen'
status: todo
type: epic
created_at: 2026-09-29T19:59:46Z
updated_at: 2026-09-29T19:59:46Z
---

De MCP-connector vraagt meerdere keren per dag om opnieuw te autoriseren. Twee
instellingen veroorzaken dat, en geen van beide is ooit bewust gekozen.

## Gemeten 2026-09-29

Volledige autorisatierondes voor `claude-connector` op één dag:

    09:10:05   13:33:18   16:13:36   19:08:06   21:48:56

Ter vergelijking, dezelfde Authelia, andere client:

    wallos     25 sep · 13 sep · 4 sep · 29 aug

De gaten tussen de rondes waren 4u23, 2u40 en 2u55 — allemaal ruim boven de
levensduur van de refresh-token. In redis stonden 1766 sessiesleutels, allemaal
met een resterende levensduur onder een uur: de vingerafdruk van voortdurend
opnieuw inloggen.

## Oorzaak 1: refresh_token 1u30

Authelia's standaard (`access_token: 1h`, `refresh_token: 90m`, nooit
aangepast). Omdat Authelia de refresh-token **roteert**, is die levensduur geen
maximale sessieduur maar een maximale **stilteperiode**: elke verversing levert
een verse token met een nieuwe klok. In de data is dat zichtbaar — om 10:10:57
staat een refresh-token zonder bijbehorende autorisatiecode, dus Claude
ververste op eigen kracht. Hij redde het alleen niet tot de volgende keer.

Gevolg: laat je de connector anderhalf uur liggen, dan moet je opnieuw
autoriseren. Bij een telefoon of een browsertab is dat de normale gang van zaken,
en dus elke ochtend opnieuw.

## Oorzaak 2: consent_mode explicit

Dit is een **overblijfsel**. `explicit` staat er omdat Authelia het verplichtte
bij de scope `authelia.bearer.authz`. Die scope is losgelaten toen bleek dat
Claude geen PAR doet (zie de gearchiveerde change `add-linny-mcp-oidc`). De
dwang verviel, de instelling bleef staan.

Authelia's eigen standaard is `auto`, en die kiest `pre-configured` zodra er een
duur is opgegeven. Wallos staat daar al op — vandaar dat die eens per twee weken
iets vraagt.

## Uitgangspunten voor de oplossing

- **De access-token blijft kort.** Dat is de enige die bij elk verzoek over de
  lijn gaat; die verlengen kost wél iets.
- **De refresh-token mag lang.** De beveiliging zit in rotatie en intrekbaarheid,
  niet in een korte levensduur — dat is ook wat de OAuth Security BCP voorschrijft
  voor publieke clients. De 90 minuten is een conservatieve standaard, geen
  veiligheidseigenschap.
- **Onthouden toestemming is niet hetzelfde als geen toestemming.** Een
  pre-configured consent vervalt zodra subject, client, scopes of audience
  wijzigen. Juist daar is toestemming voor. Vier identieke schermen per dag leidt
  ertoe dat je stopt met lezen wat je goedkeurt.
- **De sessie-cookie blijft ongemoeid.** `inactivity: 5m` beschermt een
  openstaande browser; de refresh-token ligt op Anthropic's servers. Ander risico,
  andere hefboom. Wie de vijf minuten te krap vindt, gebruikt het
  "onthoud mij"-vinkje bij het inloggen — per keer en zelfgekozen, in plaats van
  voor iedereen losser.

## Beoogd resultaat

Bij dagelijks gebruik nooit meer opnieuw autoriseren; alleen na een maand stilte.
Wallos en de andere Authelia-vhosts ongewijzigd.

## Reikwijdte

Alles speelt zich af in `modules/authelia.nix`. Dat bestand fronts ook Nextcloud,
Grafana en de rest, dus elke wijziging vraagt een regressiecontrole — eerder deze
maand legde een aanpassing daar alle vhosts vier minuten plat.
