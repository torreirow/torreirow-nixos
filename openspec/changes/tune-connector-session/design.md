# Ontwerp: levensduur en toestemming van de connector-client

## Context

Zie `proposal.md` voor de meting. Wat hier telt aan bestaande toestand:

- `modules/authelia.nix` bevat drie OIDC-clients: `wallos`, `claude-connector` en
  `linny-mcp-authz`. Er staan geen `lifespans` geconfigureerd, dus alle drie gebruiken Authelia's
  standaarden: `access_token: 1h`, `refresh_token: 90m`, `id_token: 1h`.
- `claude-connector` heeft `consent_mode: explicit`; `wallos` heeft `pre-configured` met `1M`.
- De sessie-cookie staat op `inactivity: 5m` / `expiration: 1h` — ook standaarden.
- Er is geen enkele test op dit bestand.

## Goals / Non-Goals

**Goals**

- Bij dagelijks gebruik nooit meer opnieuw autoriseren.
- De verandering isoleren tot deze ene client.

**Non-Goals**

- De sessie-cookie aanpassen. Zie beslissing 3.
- De access-token verlengen. Zie beslissing 2.
- Iets aan `wallos` of `linny-mcp-authz` veranderen.

## Decisions

### 1. Alleen de refresh-token wordt verlengd, naar 30 dagen

Authelia **roteert** refresh-tokens: bij elke verversing komt er een nieuwe en wordt de oude
verbruikt. In de gemeten data is dat zichtbaar — om 10:10:57 staat een refresh-token zonder
bijbehorende autorisatiecode, dus de client ververste op eigen kracht.

Daardoor is de levensduur een **maximale stilteperiode**, geen maximale sessieduur. Met 30 dagen
schuift de klok bij dagelijks gebruik elke dag mee.

Waarom 30 dagen en niet een week: een week laat een vakantie sneuvelen, en de grens die je kiest
moet ruim boven het normale gebruikspatroon liggen — anders verplaats je het probleem alleen.

De beveiliging van een langlevende refresh-token zit in rotatie en intrekbaarheid, niet in een korte
levensduur; dat is ook wat de OAuth Security BCP voorschrijft voor publieke clients. De 90 minuten
is een conservatieve standaard, geen veiligheidseigenschap.

### 2. De access-token blijft op 1 uur

Dat is de enige credential die bij élk verzoek over de lijn gaat. Die verlengen vergroot het venster
waarin een onderschepte token bruikbaar is, en levert niets op voor het probleem dat we oplossen —
de gebruiker merkt een verlopen access-token niet, want die wordt stil ververst.

Het profiel zet `access_token` daarom **expliciet** op `1h` in plaats van hem weg te laten. Zo staat
er zwart op wit dat het een keuze is en niet iets dat over het hoofd is gezien.

### 3. De sessie-cookie blijft ongemoeid

`inactivity: 5m` beschermt een **openstaande browser**; de refresh-token ligt op de infrastructuur
van de client. Ander risico, andere hefboom. Het globaal oprekken van de sessie zou alle vhosts
raken — Nextcloud, Grafana, Home Assistant — om een probleem op te lossen dat bij de connector zit.

Wie de vijf minuten te krap vindt, gebruikt het **"onthoud mij"-vinkje** bij het inloggen. Dat is
per keer en zelfgekozen, in plaats van voor iedereen en altijd losser. Authelia's standaard daarvoor
is een maand en staat al aan.

### 4. Toestemming onthouden is geen verzwakking

`pre-configured` vervalt zodra subject, client, scopes of audience afwijken van wat eerder is
toegestaan. Precies waar toestemming voor bedoeld is.

Vier identieke schermen per dag leidt ertoe dat je stopt met lezen wat je goedkeurt. Zeldzaamheid is
hier een beveiligingseigenschap, geen gemak.

`explicit` staat er bovendien alleen nog omdat Authelia het **verplichtte** bij de scope
`authelia.bearer.authz`. Die scope is losgelaten; de dwang bestaat niet meer. Het commentaar bij die
client beweert nog dat het een eis is — dat is onjuist geworden en moet mee.

### 5. Valideren vóór de switch, in isolatie

Een ongeldige client laat Authelia niet starten, en die beschermt alles. `authelia validate-config`
op een minimale configuratie met alleen de gewijzigde client is goedkoop en vangt precies dat.

Dat is geen theorie: op 2026-09-25 verdween `/api/verify` doordat `server.endpoints.authz` de
standaardset vervángt in plaats van aanvult, en gaven alle vhosts vier minuten lang een 500.

## Risks / Trade-offs

- **Een langere refresh-token vergroot het venster bij diefstal.** De token ligt op de servers van
  de clientaanbieder, niet op het toestel; intrekken kan in Authelia. Voor een pad dat uitsluitend
  **leesrechten** heeft (`read:*`) is dat een verdedigbare ruil.
- **De belofte is niet direct te bewijzen.** "Bij dagelijks gebruik nooit meer" blijkt pas over
  dagen. Daarom een nulmeting en een hertelling, met de afspraak dat een stijging in `design.md`
  terechtkomt in plaats van weggepoetst.
- **De aanname over rotatie is afgeleid uit de data, niet uit de documentatie.** Authelia's
  documentatie beschrijft het rotatiegedrag niet op de pagina's over lifespans en clients. Het
  bewijs is de refresh-token van 10:10:57 zonder autorisatiecode. Klopt de aanname niet, dan werkt
  30 dagen als absolute bovengrens en is het gedrag nog steeds beter dan nu, maar niet "nooit meer".

## Migration Plan

Geen migratie. Bestaande tokens houden hun oorspronkelijke levensduur; het nieuwe profiel geldt
vanaf de eerstvolgende autorisatie. De eerste ronde na de switch toont dus nog een
toestemmingsscherm — de onthouden toestemming moet eerst ontstaan.
