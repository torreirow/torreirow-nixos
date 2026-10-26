# Vikunja → Signal (herinneringen en verlopen taken)

**Aangemaakt:** 2026-10-26 · Module: `modules/vikunja-signal/` · Host: malandro

```
Vikunja (127.0.0.1:8093) ──webhook, HMAC──▶ vikunja-signal (127.0.0.1:8100) ──▶ signal-cli REST (127.0.0.1:8088)
```

## Werking

- Vikunja 2.7.0 kent `task.reminder.fired`, `task.overdue` en `tasks.overdue`. Dit zijn
  **user-directed** events: je kunt ze alleen kiezen in een webhook op gebruikersniveau
  (Instellingen → Webhooks), niet in een webhook per project.
- De ontvanger controleert `X-Vikunja-Signature` (HMAC-SHA256 hex over de body). Een
  verkeerde of ontbrekende handtekening geeft `401`. Lukt de Signal-verzending niet, dan
  stuurt de ontvanger `502` terug, zodat de fout ook in de log van Vikunja staat.
- Afzender en ontvanger komen uit `modules/signal-numbers.nix`. Dat is dezelfde
  ontvanger als bij de rustic- en wake-meldingen. Er is nog geen koppeling van
  Vikunja-gebruiker naar telefoonnummer.
- Berichten bevatten titel, project, deadline, de beschrijving (HTML → platte tekst,
  max. 600 tekens) en een link. `tasks.overdue` toont alleen titels en deadlines.
- Andere events, bijvoorbeeld uit een projectwebhook, krijgen een algemene regel
  `Vikunja: <event>`.

## Vikunja-instellingen die de module zet

| Instelling                             | Waarom                                                 |
|----------------------------------------|--------------------------------------------------------|
| `webhooks.enabled = true`              | webhooks aan                                           |
| `outgoingrequests.allownonroutableips` | anders weigert de SSRF-bescherming webhooks naar 127.0.0.1 |

De tweede instelling geldt voor alle uitgaande verzoeken van Vikunja. Dat is acceptabel
omdat registratie uit staat (`enableregistration = false`).

## Webhook aanmaken (eenmalig, per gebruiker)

1. Lees het geheim uit: `sudo cat /run/agenix/vikunja-webhook-secret` (het deel na `=`).
2. Ga in Vikunja naar Instellingen → Webhooks → nieuwe webhook:
   - Doel-URL: `http://127.0.0.1:8100/`
   - Geheim: de waarde uit stap 1
   - Events: `task.reminder.fired` en `tasks.overdue`. Kies `task.overdue` alleen als
     je per taak een apart bericht wilt in plaats van één samenvatting.
3. Stuurt Vikunja geen overdue-meldingen, controleer dan in Instellingen → Algemeen of
   herinneringen voor verlopen taken aan staan en op welk tijdstip ze komen.

## Geheim

`secrets/vikunja-webhook-secret.age` bevat `VIKUNJA_WEBHOOK_SECRET=<64 hex>`. Aanmaken of
vervangen gaat met ragenx. Let op: zonder terminal leest ragenx van **stdin** en negeert
het `$EDITOR`. Wie dat vergeet, krijgt een leeg geheim.

```bash
cd secrets
printf 'VIKUNJA_WEBHOOK_SECRET=%s\n' "$(openssl rand -hex 32)" | ragenx -e vikunja-webhook-secret.age
```

Vervang je het geheim, pas het dan daarna ook aan in de Vikunja-webhook.

## Debuggen

```bash
journalctl -u vikunja-signal -f          # "doorgestuurd: …" / "geweigerd: …" / "Signal-verzending mislukt"
curl -s http://127.0.0.1:8100/           # → ok
journalctl -u vikunja | grep -i webhook  # fouten aan de kant van Vikunja
```
