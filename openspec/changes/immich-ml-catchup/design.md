## Decisions

- **Op malandro, niet op lobos.** Malandro staat altijd aan en heeft Immich lokaal
  (`127.0.0.1:2283`); lobos hoeft niets van Immich te weten.
- **Toestandswissel i.p.v. tellen.** Een DB-telling van ontbrekende assets blijft hangen op assets
  die nooit een embedding krijgen (bv. zonder preview) en zou dan elke 10 min starten. Starten bij
  "down → up", bij de eerste run en hooguit elke 6 uur is genoeg en goedkoop: `force=false` slaat
  verwerkte assets over.
- **Oud jobs-endpoint.** `PUT /api/jobs/:name` is in v2.4 deprecated, maar de opvolger
  (`/api/queues/:name`) kent alleen pauzeren; starten kan alleen via het oude endpoint. Bij een
  Immich-upgrade controleren (test faalt dan niet, de dienst wel: HTTP-fout = exit 1).
- **400 "Job is already running" = gelukt.**
- **Sleutel niet in de proceslijst:** header via `-H @<(...)`; `LoadCredential` + `DynamicUser`.
- **Sleutel met minimaal recht** (`job.create`) i.p.v. inloggen met het admin-wachtwoord.
