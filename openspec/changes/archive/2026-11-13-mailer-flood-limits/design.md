# Design

## Context

Zie `proposal.md` — Why. Bestaand gedrag in `modules/mailer.nix`:

- Eén PHP-script (gegenereerd met `writeTextFile`) onder een PHP-FPM pool, achter
  nginx met `limit_req zone=contactform rate=5r/m burst=3`.
- `ratelimit.json` in `cfg.stateDir`, onder `flock`, met regels `{t, to}` en een
  sliding window van 24 uur; limieten zijn `totalPerDay`, `perRecipientPerDay` en
  `perRecipientPerHour`.
- Validatie: origin/referer-host tegen `recipients`, Cap `siteverify`, honeypot,
  daarna `mail()` via postfix.

## Goals / Non-Goals

**Goals**

- Budget scheiden per formuliersoort zonder tweede endpoint of tweede domein.
- Misbruik begrenzen op drie assen: per soort, per IP, en totaal per dag.
- Operationeel kunnen ingrijpen zonder rebuild.

**Non-Goals**

- Geen wachtrij, geen retries, geen opslag van berichten.
- Geen dashboard of metrics-endpoint; journald blijft de bron.
- Geen wijziging aan de sites of aan de Cap-configuratie.

## Decisions

**1. `soort` als formulierveld, geen pad of subdomein.**
De origin-whitelist routeert op host; een tweede endpoint (`/send/signup`) zou een
tweede nginx-locatie, tweede Cap-config en tweede vhost vragen. Een veld is één regel
in het formulier en één lookup in het script. Alternatief (pad) verworpen: meer
infra, geen voordeel.

**2. Buckets in `limits.kinds` met `contact` als default.**
`limits.kinds = { contact = { perHour = 3; perDay = 10; }; signup = { perHour = 30; perDay = 80; }; }`
en `totalPerDay = 150`. Onbekende `soort` → `contact`, zodat een nieuwe site niets
hoeft te weten van buckets.

**3. Per-IP-teller met gehasht adres.**
`sha256(salt + ip)` met een salt in `cfg.stateDir/salt` (bij eerste gebruik
aangemaakt, mode 0400). Ruw IP bewaren is niet nodig voor de telling en is privacy-
gevoelig; de hash is genoeg om te tellen en te dedupliceren.

**4. Dedupe op `email` + `soort` + `meetup`.**
Hash van die drie, 24 uur bewaard. Antwoord bij een duplicaat is 200 zonder mail, zodat
een bot niet kan afleiden of een adres al aangemeld is.

**5. Kill switch als bestand.**
`${stateDir}/disabled` → 503 met dezelfde nette foutpagina als bij een volle bucket.
Bestand aanmaken/verwijderen met `sudo touch`/`rm`; geen `nixos-rebuild` nodig. Een
optie in de module zou trager zijn en de state hoort bij de runtime, niet bij de bouw.

**6. `ratelimit.json` blijft één bestand onder `flock`.**
Regels worden `{t, to, k, ip, d}`; onbekende velden in bestaande bestanden worden
genegeerd. Bij 150 regels per dag is de bestandsgrootte triviaal; geen database nodig.
Alternatief (valkey, die er al staat voor Cap) verworpen: extra afhankelijkheid en
container-roundtrip per request voor een bestand van enkele kB's.

## Risks / Trade-offs

- [Gedeelde IP's (café-wifi, NAT) raken de 8/dag] → 8 is bewust ruim boven één
  bezoeker; bij structurele klachten is het een configuratiewaarde.
- [Flood met veel IP's en opgeloste Cap] → bovengrens blijft 80 signup-mails per dag
  en 150 totaal; dat is de bewuste schadebeperking.
- [Hash-salt kwijt] → tellers beginnen opnieuw; gevolg is hooguit een ruimere dag,
  geen fout. Salt wordt niet geroteerd zonder de tellers te resetten.
- [Klok sprong achteruit] → window filtert op `t > now - 86400`; een sprong terug kan
  tijdelijk ruimte geven. Acceptabel voor deze dreiging.
- [Vergeten `soort` mee te sturen] → bericht valt in de contactbucket (3/10); de
  site-change stuurt het veld altijd mee en heeft een test die dat controleert.

## Migration Plan

1. Module aanpassen en `nixos-rebuild switch` op malandro; bestaande sites merken
   niets (geen `soort` = `contact`, dezelfde limieten).
2. Site-change uitrollen die `soort=signup` meestuurt.
3. Verificatie: 4e contact-POST in een uur → 429; 31e signup-POST → 429; 9e POST vanaf
   één IP → 429; dubbele POST → 200 zonder mail; `disabled` → 503.
4. Rollback: vorige commit van de module; `ratelimit.json` blijft leesbaar.

## Open Questions

Geen.
