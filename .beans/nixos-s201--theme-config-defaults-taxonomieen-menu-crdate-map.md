---
# nixos-s201
title: Theme-config-defaults (taxonomieen, menu, crdate-map, enableGitInfo)
status: completed
type: task
priority: normal
created_at: 2026-09-03T14:52:56Z
updated_at: 2026-09-03T16:51:47Z
parent: nixos-al4j
blocked_by:
    - nixos-avpo
---

Theme-config-defaults zodat een notebook een minimale `hugo-web.yaml` overhoudt.

## Todo
- [ ] taxonomieën (customer/project/type/tags), menu (Customers/Projects/Types/Tags)
- [ ] `frontmatter.date = [crdate, date, publishDate, lastmod]`
- [ ] `enableGitInfo: true` + `params.geekdocPageLastmod: true` (voor de Updated-datum)
- [ ] geekdoc-params (search aan, tags-to-menu, back-to-top, …) als sensible defaults



DONE: theme hugo.yaml levert taxonomies+menu+params (die MERGEN uit theme-config). Let op: markup/frontmatter/pagination/enableGitInfo mergen NIET uit een theme -> horen in notebook hugo-web.yaml (empirisch getest).
