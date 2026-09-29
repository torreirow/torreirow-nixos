---
# nixos-0uww
title: Eigen lifespan-profiel voor de connector
status: todo
type: task
created_at: 2026-09-29T20:00:06Z
updated_at: 2026-09-29T20:00:06Z
parent: nixos-b25k
---

Per-client levensduur via een benoemd profiel onder
`identity_providers.oidc.lifespans.custom`, waar de client met `lifespan` naar
verwijst.

    lifespans:
      custom:
        connector:
          access_token: '1h'      # ongewijzigd
          refresh_token: '30d'

- [ ] Profiel toevoegen en de client eraan koppelen
- [ ] **Access-token expliciet op 1h laten.** Vastleggen in commentaar waarom:
      dat is de enige die bij elk verzoek meegaat; alleen de refresh-token wordt
      verlengd
- [ ] Controleren dat andere clients (wallos) het profiel NIET erven — de
      globale lifespans blijven ongemoeid
- [ ] `validate-config` in isolatie voor de switch
