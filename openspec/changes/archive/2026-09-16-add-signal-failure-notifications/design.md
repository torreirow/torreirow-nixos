# Design — faalmeldingen van user-services naar Signal

## De storing die dit aantoonde

```
  9 sep 2026                                              16 sep 2026
  ├──────────────────────────────────────────────────────────┤
  419 mislukte runs, 0 geslaagde, elke 10 minuten opnieuw

  in de journal:   "Failed to start Nextcloud sync (docs)."      ← dat was alles
  werkelijke fout: HTTP 429 (brute-force-throttling), onder een verlopen wachtwoord
```

Twee onafhankelijke gaten moesten dicht: de unit zweeg (`--silent`), en niemand keek.

## Beslissing 1 — `--silent` mag niet de default zijn

`nextcloudcmd --silent` onderdrukt ook foutuitvoer. De vlag zat hardgecodeerd in `mkExecStart`.
Nu achter `quiet`, default `false`.

De afweging is journal-volume tegen zichtbaarheid. Een sync die elke tien minuten een paar regels
schrijft is goedkoop; een storing die zeven dagen onzichtbaar blijft niet. Wie het volume toch
kwijt wil kan `quiet = true` zetten — maar dan is de `onFailure`-haak geen luxe meer.

## Beslissing 2 — Waarom via Home Assistant en niet via signal-cli

`modules/rustic-backup.nix` op malandro stuurt rechtstreeks naar de signal-cli REST API. Dat
patroon is hier niet bruikbaar:

```
  malandro                                   lobos
  ┌────────────────────────────┐             ┌──────────────────────────┐
  │ signal-cli REST            │             │                          │
  │ LISTEN 127.0.0.1:8088  ────┼──✗ ─────────┤ onbereikbaar             │
  │                            │             │                          │
  │ Home Assistant             │◄── HTTPS ───┤ /api/services/notify/…   │
  │ notify.signal_maria        │             │ token uit agenix         │
  └────────────────────────────┘             └──────────────────────────┘
```

Gemeten: `ss -tlnp` op malandro toont `LISTEN 127.0.0.1:8088`; een TCP-probe vanaf lobos faalt.
Home Assistant is wél bereikbaar (`https://homeassistant.toorren.net` → HTTP 200) en heeft
`notify.signal_maria` al geconfigureerd, met `notify.wouter` (Telegram) ernaast.

**Het verworpen alternatief: een SSH-hop naar malandro.** Technisch simpel, maar op lobos is `rbw`
de ssh-agent en die kan gelockt zijn. Dan faalt juist de meldingsweg — een meldingssysteem dat
stuk gaat precies wanneer je het nodig hebt, is erger dan geen meldingssysteem.

Het token bestond al als `secrets/ha-token.age` (recipients: `users` + beide workstation-hostkeys)
en werd nergens gebruikt. Geldigheid geverifieerd met `ragenx -d` → HA `/api/` gaf HTTP 200.

## Beslissing 3 — Eén template-unit, niet één unit per service

```
  systemd.user.services."notify-signal@"
        ▲                    ▲
        │                    │
  nextcloud-sync-docs   remarkable-sync
  OnFailure=notify-signal@%N.service
```

`%N` is de naam van de unit waarin het staat, dus systemd vult zelf de juiste instance in.
Geverifieerd na de switch: `OnFailure=notify-signal@nextcloud-sync-docs.service` en
`notify-signal@remarkable-sync.service`. Eén template bedient alles wat er later bij komt.

## Beslissing 4 — Het bericht bevat context, geen alarmbel

Alleen "unit X gefaald" dwingt je alsnog in te loggen. Het script plakt daarom de laatste vijf
journalregels van de falende unit erbij. Bij de storing die dit ontketende zou dat direct het
verschil hebben gemaakt — mits `--silent` weg was, wat beslissing 1 regelt. De twee beslissingen
zijn dus niet los te zien: melden zonder logregels is een alarmbel zonder adres.

## Beslissing 5 — `--fail-with-body`, want anders herhaalt de fout zich hier

De eerste versie gebruikte `curl -s … || echo mislukt`. Gemeten tegen een niet-bestaande
notify-dienst:

```
curl -s               → exit 0   bij HTTP 400    ← geweigerde melding zag er geslaagd uit
curl --fail-with-body → exit 22  bij HTTP 400    ← unit faalt, mét de respons in de journal
```

Exact dezelfde klasse fout als `--silent`: iets dat niets doet en zich voordoet als succes — in de
module die dat juist moet voorkomen. Nu faalt het meldscript hoorbaar, inclusief de HTTP-respons.

## Beslissing 6 — Geen melding bij een afwezig apparaat

`remarkable-sync` eindigt met exit 0 als de reMarkable slaapt of losgekoppeld is. Dat is geen
fout, en `OnFailure` vuurt er dus niet op. Zou dat wél zo zijn, dan kreeg je elke twee minuten een
Signal-bericht en had je het kanaal binnen een dag gedempt — waarmee je terug bij af was.
