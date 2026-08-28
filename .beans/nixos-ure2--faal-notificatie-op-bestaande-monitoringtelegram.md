---
# nixos-ure2
title: Faal-notificatie op bestaande monitoring/Telegram
status: completed
type: task
priority: normal
created_at: 2026-08-28T08:08:35Z
updated_at: 2026-08-28T09:07:33Z
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
