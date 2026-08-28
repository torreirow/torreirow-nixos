---
# nixos-ure2
title: Faal-notificatie via Signal (signal-cli REST API)
status: completed
type: task
priority: normal
created_at: 2026-08-28T08:08:35Z
updated_at: 2026-08-28T09:27:10Z
parent: nixos-sd4i
blocked_by:
    - nixos-jznr
---

Bij falen van een dump- of backup-service een melding sturen.

## Context
- Bestaande secrets: module-monitoring-telegram_bot_token/chat_id, module-monitoring-slack_webhook.
- Zie modules/monitoring/ voor het bestaande notificatiepatroon.

## Taken
- [ ] OnFailure= handler-service die Telegram (of Slack) notify stuurt
- [ ] koppelen aan pg-dump / mariadb-dump / vaultwarden-dump / rustic-backup
- [ ] testen door een service bewust te laten falen


## Bijgewerkt 2026-08-28 — Signal i.p.v. Telegram
Notificatie gaat via de lokale signal-cli REST API (`http://127.0.0.1:8088/v2/send`, jq bouwt de JSON),
afzender `+31612652352` → ontvanger `+31636201589` (zelfde als HA signal_maria). De twee agenix
Telegram-secrets vervallen; Signal-nummers zijn niet geheim en staan plain in de module. Getest: HTTP 201 + ontvangen.
