---
# nixos-pbph
title: 'lindexer: index bouwen vóór serve en bijhouden met watch'
status: completed
type: task
priority: normal
created_at: 2026-09-25T07:44:52Z
updated_at: 2026-09-25T11:30:45Z
parent: nixos-m0vn
blocked_by:
    - nixos-dqs2
---

`linny-mcp serve` **leest** alleen een index; het bouwt er nooit een. Zonder deze story zien
MCP-clients nul documenten, en blijft dat zo voor alles wat via git-sync binnenkomt — `serve`
herindexeert namelijk alleen zijn *eigen* schrijfacties.

mipmip liep hier tegenaan ná zijn deployment en heeft er een losse change voor gemaakt
(`add-linny-mcp-indexer`). Wij nemen het meteen mee.

## Vorm
Eén unit met twee fasen, met het `lindexer`-binary uit hetzelfde `linny-mcp`-pakket:

- `ExecStartPre` = `lindexer build ...` — volledige rebuild. ExecStartPre is klaar voordat de unit
  als gestart geldt, dus `linny-mcp.service` (die erna geordend is) ziet een gevulde index.
- `ExecStart` = `lindexer watch ...` — fsnotify, herbouwt bij elke corpuswijziging: zowel
  git-sync-pulls als agent-schrijfacties.

De gegenereerde index (SQLite + JSON) hoort in de wegwerp-stateDir, **nooit** in de git-tracked
corpus — anders commit en pusht git-sync index-artefacten.

## Todo
- [x] `systemd.services.linny-mcp-index`: `ExecStartPre` = build, `ExecStart` = watch
- [x] ordening: `after`/`requires` de clone-unit, `before = linny-mcp.service`, `wantedBy = multi-user.target`
- [x] draaien als de service-user; `Restart = on-failure`
- [x] index-output naar de stateDir; controleer dat `git status` in het corpus schoon blijft
- [x] verifieer: verse boot -> MCP-query levert direct documenten (geen lege index)
- [x] verifieer: notitie elders bewerkt + gepusht -> na de pull doorzoekbaar zonder handmatige reindex
- [x] verifieer: unit herstarten -> volledige build vóór watch, index weer correct

## Summary of Changes

`linny-mcp-index.service`: `ExecStartPre` = `lindexer build`, `ExecStart` = `lindexer watch`,
geordend na de clone en vóór `linny-mcp.service`. Index naar de wegwerp-state-dir, niet in het corpus.

Echt getoetst tegen het corpus: `lindexer build` met exact deze vlaggen leverde **117 records** en
een werkende FTS-zoekopdracht. Eén notitie zonder frontmatter werd overgeslagen en staat niet in de
index -- doorgegeven aan nixos-zets.
