## Context

Zie `proposal.md` - Why. De huidige `bind N` (net opgeleverd) doet:
`run-shell 'tmux has-session -t TorrLinny 2>/dev/null || smug start notepad --detach' \;
switch-client -t TorrLinny`. De conditionele richting maakt de `\; switch-client`-vorm te beperkt;
alle logica moet in één `run-shell` zodat de tak (main vs TorrLinny) kan worden gekozen.

De `main`-sessie bestaat betrouwbaar: `systemd.user.services.tmux` in `home/tmux.nix` start de
server met `new-session -d -s main`.

## Goals / Non-Goals

**Goals:**
- Eén toets die toggelt: in `TorrLinny` → `main`; elders → `TorrLinny` (start indien nodig).
- Idempotente start en `switch-client` (geen popup) behouden.

**Non-Goals:**
- `notepad.yml`/sessienaam `TorrLinny` wijzigen.
- Een algemene N-way toggle of "vorige sessie"-gedrag; het doel is expliciet `TorrLinny` ↔ `main`.

## Decisions

**Alle logica in één `run-shell`.** De tak hangt af van de huidige sessie, dus de losse
`\; switch-client` vervalt. tmux expandeert `#{session_name}` in `run-shell` naar de sessie van de
actieve pane — dat is de toggle-conditie:

```
bind N run-shell 'if [ "#{session_name}" = "TorrLinny" ]; then \
    tmux switch-client -t main 2>/dev/null || tmux switch-client -l; \
  else \
    tmux has-session -t TorrLinny 2>/dev/null || smug start notepad --detach; \
    tmux switch-client -t TorrLinny; \
  fi'
```

**Fallback `|| switch-client -l` bij het terugschakelen.** Mocht `main` onverhoopt niet bestaan
(server anders opgestart), dan valt de binding terug op de laatst-gebruikte sessie i.p.v. stil te
falen. `main` is de normale, door de systemd-unit gegarandeerde route.

**`#{session_name}` i.p.v. een shell-var.** tmux vult de format vóór het uitvoeren van de shell in;
geen afhankelijkheid van `$TMUX`/omgeving. In de nix `''`-string is `#{...}` veilig (geen `$`,
dus geen interpolatie).

## Risks / Trade-offs

- [Toggle vanuit een derde sessie X gaat naar TorrLinny, en de volgende N gaat naar `main`, niet
  terug naar X] → bewuste keuze: de toggle is gedefinieerd als `TorrLinny` ↔ `main`, niet als
  "vorige sessie". Wie "terug naar waar ik was" wil, gebruikt tmux' eigen `switch-client -l`.
- [`main`-sessie hernoemd/afwezig] → fallback op `switch-client -l` vangt het af; anders geen
  effect. De systemd-unit houdt `main` in stand.
