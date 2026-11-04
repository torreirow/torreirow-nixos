---
# nixos-nqza
title: 'RustDesk: eigen ID-/relay-server op malandro via Nebula (later)'
status: draft
type: feature
priority: low
created_at: 2026-11-04T21:35:12Z
updated_at: 2026-11-04T21:35:12Z
---

Eigen RustDesk ID-/relay-server (hbbs/hbbr, pakket `rustdesk-server`) op malandro, alleen bereikbaar via
Nebula (10.77.0.1), zodat mpenzi en lobos niet meer via de publieke RustDesk-servers lopen.

Context (2026-11-04):
- Op mpenzi draait RustDesk alleen als Maaike de app zelf opent (Wayland: `rustdesk --service` doet
  niets, bewust geen autostart). Met de app dicht is er geen verbinding naar 21115-21119 (gecontroleerd).
- Publieke toegang via ID vraagt het tijdelijke wachtwoord op haar scherm + haar klik + Wayland-
  schermdeel-toestemming. Risico is klein; daarom "later".
- Optie dummy-server (`custom-rendezvous-server = '127.0.0.1'`) afgewezen: permanente rode
  "Niet gereed"-melding in Maaike's venster.

Wat te doen:
- malandro: hbbs + hbbr, luisteren/firewall alleen op `nebula.toorren` (21115-21119); sleutelpaar van
  hbbs bewaren (privé-sleutel via agenix of in de state-dir, niet in de repo).
- mpenzi (Maaike's eigen `~/.config/rustdesk/RustDesk2.toml`, via de seed/herstel-app uit epic
  nixos-kzxu): `custom-rendezvous-server`, `relay-server` = 10.77.0.1, `key` = publieke hbbs-sleutel.
- lobos-client: zelfde instellingen.
- Nebula-firewall: inbound 21115-21119 op malandro alleen van lobos en mpenzi.
- Belasting verwacht: ~10-30 MB RAM, CPU ~0; relay alleen als direct verbinden faalt.
