---
# nixos-vza6
title: 'wtoorren-admin: aws-deel (bmc/race, ~/.aws/config achter aws.enable)'
status: todo
type: task
priority: normal
created_at: 2026-11-04T20:39:33Z
updated_at: 2026-11-04T20:52:07Z
parent: nixos-tesy
blocked_by:
    - nixos-xa9h
---

AWS-deel `home/profiles/wtoorren-admin/aws.nix`.

- Pakketten bmc en race uit de flake-inputs (`bmc.packages.<system>.bmc`, `race.packages.<system>.race`),
  via `extraSpecialArgs` of een overlay; altijd installeren als het profiel aan staat.
- `~/.aws/config`-generatie (logica uit `home/awsconf.nix`) alleen bij `toorren.admin.aws.enable`.
  Hergebruik `home/awsconf.nix` als dat kan zonder lobos te veranderen.
- Controleer of race aliassen naar repo-scripts nodig heeft of dat het pakket de commando's levert;
  geen verwijzingen naar niet-bestaande paden op een server.
- `~/.config/bmc/config.json` WEL beheren (zie epic, regel "bmc-config"): zelfde mfa/totp_script/profile_scripts als lobos, maar copy/paste-commando dat headless over ssh werkt (OSC 52 / tmux-buffer i.p.v. wl-copy/wl-paste). Bevat geen geheimen, alleen rbw-itemnamen. Lobos zelf niet omzetten.
