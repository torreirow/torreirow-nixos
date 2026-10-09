# msmtp / agenix secret-pad

Waarom age.secrets een expliciet 'path' nodig heeft om op /run/secrets/<naam> te verschijnen.

> Verplaatst uit CLAUDE.md (Huidige Status) om de sessie-context slank te houden.

### Sessie 2026-05-29 - msmtp agenix secret pad - OPGELOST

**Probleem:** msmtp kon geen mail versturen omdat `/run/agenix/msmtp-password` niet bestond.

**Oorzaak:**
Agenix plaatst secrets in `/run/agenix.d/<generatie>/` en maakt symlinks aan **alleen als je een expliciet `path` opgeeft** in de secret definitie. Zonder `path` wordt de secret wel gedecrypteerd naar `/run/keys/<owner>/<name>`, maar er komt geen symlink op het verwachte pad.

**Oplossing:**
```nix
age.secrets.msmtp-password = {
  file = ../../secrets/msmtp-password.age;
  path = "/run/secrets/msmtp-password";  # expliciet pad vereist!
  owner = "wtoorren";
  mode = "0400";
};
```
En in de config die het secret gebruikt, verwijzen naar dat expliciete pad.

**Les:**
- ✅ Altijd `path = "/run/secrets/<naam>"` opgeven bij `age.secrets` als de secret via een config-bestand wordt gelezen
- ✅ Zonder `path`: secret bestaat alleen in `/run/keys/<owner>/<naam>` (interne agenix opslag)
- ✅ Met `path`: agenix maakt een symlink aan op het opgegeven pad → `/run/keys/<owner>/<naam>`
- ✅ Controleer of secrets bestaan met: `ls -la /run/secrets/` en `ls -la /run/keys/<owner>/`

**Bestanden gewijzigd:**
- `hosts/lobos/mail.nix` - `path` toegevoegd aan secret, `passwordeval` pad bijgewerkt

**Status:** ✅ msmtp verstuurt mail via AWS SES
