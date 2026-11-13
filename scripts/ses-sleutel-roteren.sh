#!/usr/bin/env bash
# Roteert de SES-SMTP-sleutel van Postfix op malandro.
#
# Gebruik (vanaf de repo-root, met geldige AWS-sessie):
#   AWS_PROFILE=499164406685-wouter scripts/ses-sleutel-roteren.sh AKIA...OUDE_SLEUTEL
#
# Wat het doet:
#   1. zoekt de IAM-user bij de oude sleutel
#   2. maakt een nieuwe access key voor die user
#   3. leidt daaruit het SES-SMTP-wachtwoord af (AWS SigV4-afleiding, versie 4)
#   4. schrijft secrets/postfix-sasl-password.age opnieuw (via ragenx, stdin)
# Het geheim wordt nergens getoond of op schijf gezet.
#
# Daarna zelf: deployen, testmail, oude sleutel op Inactive zetten (zie uitvoer).
set -euo pipefail

OLD_KEY="${1:?gebruik: $0 <oude-access-key-id>}"
REGION="eu-central-1"
: "${AWS_PROFILE:?zet AWS_PROFILE}"

[ -f secrets/secrets.nix ] || { echo "Draai dit vanaf de repo-root." >&2; exit 1; }

user=$(aws iam get-access-key-last-used --access-key-id "$OLD_KEY" \
  --query UserName --output text)
echo "IAM-user: $user"

count=$(aws iam list-access-keys --user-name "$user" \
  --query 'length(AccessKeyMetadata)' --output text)
if [ "$count" -ge 2 ]; then
  echo "User '$user' heeft al 2 sleutels; eerst een ongebruikte verwijderen." >&2
  aws iam list-access-keys --user-name "$user" --output table >&2
  exit 1
fi

read -r new_id new_secret < <(aws iam create-access-key --user-name "$user" \
  --query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text)

smtp_pw=$(SECRET="$new_secret" REGION="$REGION" python3 -I -c '
import base64, hashlib, hmac, os
def sign(k, m): return hmac.new(k, m.encode(), hashlib.sha256).digest()
s = sign(("AWS4" + os.environ["SECRET"]).encode(), "11111111")
for part in (os.environ["REGION"], "ses", "aws4_request", "SendRawEmail"):
    s = sign(s, part)
print(base64.b64encode(bytes([4]) + s).decode())
')
unset new_secret

(
  cd secrets
  printf '[email-smtp.%s.amazonaws.com]:587 %s:%s\n' "$REGION" "$new_id" "$smtp_pw" \
    | ragenx -e postfix-sasl-password.age
)
unset smtp_pw

cat <<EOF

Nieuwe sleutel aangemaakt: $new_id (user: $user)
secrets/postfix-sasl-password.age is bijgewerkt.

Volgende stappen:
  1. Deploy malandro.
  2. Testmail: echo test | ssh malandro 'sendmail wouter@technative.eu'
  3. Oude sleutel uit:
     aws iam update-access-key --user-name $user --access-key-id $OLD_KEY --status Inactive
  4. Na ~1 week zonder problemen:
     aws iam delete-access-key --user-name $user --access-key-id $OLD_KEY
EOF
