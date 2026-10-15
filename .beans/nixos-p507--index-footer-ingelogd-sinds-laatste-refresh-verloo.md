---
# nixos-p507
title: 'Index-footer: ingelogd sinds, laatste refresh, verloop onbekend'
status: completed
type: task
priority: normal
created_at: 2026-10-15T13:54:30Z
updated_at: 2026-10-15T14:09:14Z
parent: nixos-s630
blocked_by:
    - nixos-g3id
---

In generate_index_html de footer uitbreiden onder "Laatste update:":

- [x] Ingelogd sinds: <datum tijd> (N dagen)
- [x] Laatste refresh: <datum tijd>
- [x] Token-verloop: onbekend (Magister geeft dit niet prijs)
- [x] Nette fallback als de status niet beschikbaar is

## Summary of Changes

Footer toont 'Ingelogd sinds' (+ dagen, enkelvoud 'dag'), 'Laatste refresh' en 'Token-verloop: onbekend'. Onbekend wordt 'onbekend'. De aanroepen in main() geven de status mee. Unit-tests: FooterTest.
