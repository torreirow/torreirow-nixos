# hyprlock 0.9.5 claimt de vingerafdruksensor maar één keer: faalt de Claim (sensor nog bezet door de
# vorige instantie, of fprintd sluit net af na een resume), dan is fingerprint dood voor die lock-sessie.
# Patch: bij wake opnieuw claimen (port van upstream PR #1049) + Claim-retry met backoff.
# Zie openspec change hyprlock-fingerprint-unlock (design decision 5).
# Verwijderen zodra upstream een gelijkwaardige fix heeft. Let op: 0.9.6 heeft regressie #1074.
self: super: {
  hyprlock = super.hyprlock.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./patches/hyprlock-fprint-reclaim.patch ];
  });
}
