#!/usr/bin/env bash
# Provisioning van bobadela1 (Linux Mint / geen NixOS) voor Nextcloud-op-JuiceFS.
# Draai dit VANAF malandro (heeft agenix + de host-key om de secrets te decrypten).
# Idempotent: veilig om te herdraaien. Zie hosts/bobadela1/README.md voor context.
#
# Vereist: ssh bobadela1 met passwordless sudo; agenix-secrets in ../../secrets/.
set -euo pipefail

BOBA=bobadela1
BOBA_IP=192.168.2.67
MAL_IP=192.168.2.52
KEY=/etc/ssh/ssh_host_ed25519_key
SECRETS_DIR="$(cd "$(dirname "$0")/../../secrets" && pwd)"

dec() { sudo agenix -d "$SECRETS_DIR/$1" -i "$KEY"; }

echo "== 1. PostgreSQL 16 =="
ssh "$BOBA" 'command -v psql >/dev/null || { sudo apt-get update -qq && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq postgresql-16 postgresql-client-16; }'
ssh "$BOBA" "sudo tee /etc/postgresql/16/main/conf.d/juicefs.conf >/dev/null <<'CONF'
wal_level = logical
listen_addresses = 'localhost,${BOBA_IP}'
max_wal_senders = 10
max_replication_slots = 10
password_encryption = scram-sha-256
CONF
sudo grep -q 'juicefs_meta.*repl.*${MAL_IP}' /etc/postgresql/16/main/pg_hba.conf || echo 'host juicefs_meta repl ${MAL_IP}/32 scram-sha-256' | sudo tee -a /etc/postgresql/16/main/pg_hba.conf
for C in 127.0.0.1/32 ::1/128; do sudo grep -q \"juicefs_meta    juicefs    \$C\" /etc/postgresql/16/main/pg_hba.conf || echo \"host juicefs_meta juicefs \$C scram-sha-256\" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf; done
sudo systemctl restart postgresql@16-main"

echo "== 2. Rollen + database =="
REPL_PW="$(dec juicefs-repl-password.age)"
DB_PW="$(dec juicefs-db-password.age)"
ssh "$BOBA" "REPL_PW='$REPL_PW' DB_PW='$DB_PW' sudo -E -u postgres psql -v ON_ERROR_STOP=1" <<'SQL'
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='repl') THEN CREATE ROLE repl WITH REPLICATION LOGIN PASSWORD :'x'; END IF;
END $$ \gset
SQL
# (rol/db-aanmaak: zie README; hierboven vereenvoudigd — gebruik de losse psql-commando's uit de historie)

echo "== 3. Secrets uitrollen naar /etc/juicefs (root 0400) =="
ssh "$BOBA" 'sudo install -d -m 0700 /etc/juicefs'
dec juicefs-rsa-key.age | ssh "$BOBA" 'sudo tee /etc/juicefs/rsa-key.pem >/dev/null && sudo chmod 0400 /etc/juicefs/rsa-key.pem'
{
  echo "ACCESS_KEY=$(dec juicefs-s3-env.age | sed -n 's/^AWS_ACCESS_KEY_ID=//p')"
  echo "SECRET_KEY=$(dec juicefs-s3-env.age | sed -n 's/^AWS_SECRET_ACCESS_KEY=//p')"
  echo "META_PASSWORD=$(dec juicefs-db-password.age)"
  echo "JFS_RSA_PASSPHRASE=$(dec juicefs-format-passphrase.age)"
} | ssh "$BOBA" 'sudo tee /etc/juicefs/juicefs.env >/dev/null && sudo chmod 0400 /etc/juicefs/juicefs.env'

echo "== 4. JuiceFS-client (v1.2.3) =="
ssh "$BOBA" 'command -v juicefs >/dev/null || { cd /tmp && curl -fsSL -o j.tgz https://github.com/juicedata/juicefs/releases/download/v1.2.3/juicefs-1.2.3-linux-amd64.tar.gz && tar xzf j.tgz juicefs && sudo install -m0755 juicefs /usr/local/bin/juicefs && rm -f j.tgz juicefs; }'

echo "== 5. Volume formatteren (encrypted) — ALLEEN als nog niet geformatteerd =="
ssh "$BOBA" 'sudo bash -c "set -a; . /etc/juicefs/juicefs.env; set +a; juicefs status postgres://juicefs@localhost:5432/juicefs_meta >/dev/null 2>&1 || juicefs format --storage s3 --bucket https://wto-s3-bucket.s3.eu-central-1.amazonaws.com --encrypt-rsa-key /etc/juicefs/rsa-key.pem postgres://juicefs@localhost:5432/juicefs_meta juicefs"'

echo "== 6. systemd mount-unit + boot-ordering =="
ssh "$BOBA" 'sudo install -d -m0700 /var/jfsCache; sudo install -d -m0755 /etc/systemd/system/docker.service.d'
# unit-bestanden staan in hosts/bobadela1/ (juicefs-nextcloud.service, 10-juicefs-ncdata.conf)
scp "$(dirname "$0")/juicefs-nextcloud.service" "$BOBA":/tmp/ && ssh "$BOBA" 'sudo mv /tmp/juicefs-nextcloud.service /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl enable juicefs-nextcloud.service'
scp "$(dirname "$0")/10-juicefs-ncdata.conf" "$BOBA":/tmp/ && ssh "$BOBA" 'sudo mv /tmp/10-juicefs-ncdata.conf /etc/systemd/system/docker.service.d/ && sudo systemctl daemon-reload'

echo "Klaar. Voor de EERSTE keer: volg de migratie-stappen in README.md (AIO stoppen → rsync → cutover)."
