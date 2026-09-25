#!/usr/bin/env bash
# Toont aan dat het publieke MCP-endpoint zonder Authelia-inlog niets prijsgeeft.
#
# Draaien OP malandro (heeft sudo nodig voor de twee secrets):
#     sudo -v && ./verify-live.sh
#
# De scherpste toets is niet "onzin wordt geweigerd" maar test 6: een ECHT,
# door Authelia als `active` bevestigd token van een ANDERE client wordt ook
# geweigerd. Zonder de client_id-controle in linny-mcp-authz zou elk geldig
# token op deze Authelia het notitieboek openen -- ook dat van Wallos.
#
# Geen enkele tokenwaarde wordt geprint.
set -u

URL=${URL:-https://linny-mcp.toorren.net/mcp}
TUNNEL=${TUNNEL:-http://127.0.0.1:8096/mcp}
AUTHELIA=${AUTHELIA:-http://127.0.0.1:9091}
BODY='{"jsonrpc":"2.0","id":1,"method":"initialize"}'

fails=0
want() { # want <verwacht> <gekregen> <omschrijving>
  if [ "$1" = "$2" ]; then
    printf '  [OK  ] %-46s %s\n' "$3" "$2"
  else
    printf '  [FOUT] %-46s %s (verwacht %s)\n' "$3" "$2" "$1"
    fails=$((fails + 1))
  fi
}

code() { curl -sS -o /dev/null -w '%{http_code}' "$@"; }

echo "publiek endpoint zonder geldige aanmelding"
want 401 "$(code -X POST -H 'Content-Type: application/json' -d "$BODY" "$URL")" \
     "zonder Authorization-header"
want 401 "$(code -X POST -H 'Authorization: Bearer onzin' -d "$BODY" "$URL")" \
     "onzin-token"
want 401 "$(code -X POST -H 'Authorization: Bearer authelia_at_AAAAAAAAAAAAAAAA' -d "$BODY" "$URL")" \
     "vervalst authelia_at_-voorvoegsel"
want 401 "$(code -X POST -H 'Authorization: Basic d3Rvb3JyZW46eA==' -d "$BODY" "$URL")" \
     "Basic in plaats van Bearer"
want 401 "$(code https://linny-mcp.toorren.net/healthz)" \
     "healthz zonder token"
want 401 "$(code https://linny-mcp.toorren.net/authz-mcp)" \
     "interne authz-location van buiten"

echo "het interne token is aan de publieke kant waardeloos"
INTERN=$(sudo sed -n 's/.*Bearer \([^"]*\)".*/\1/p' /run/agenix/linny-mcp-nginx-token)
if [ -z "$INTERN" ]; then echo "  (overgeslagen: interne token niet leesbaar)"; else
  want 401 "$(code -X POST -H "Authorization: Bearer $INTERN" -d "$BODY" "$URL")" \
       "publiek geweigerd"
  # 400 en niet 401: linny-mcp accepteert het token en struikelt over het
  # onvolledige MCP-verzoek. Precies dat verschil is het bewijs.
  want 400 "$(code -X POST -H "Authorization: Bearer $INTERN" \
       -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
       -d "$BODY" "$TUNNEL")" "via de tunnel wel geaccepteerd"
fi

echo "een ECHT Authelia-token van een andere client"
SECRET=$(sudo cat /run/agenix/linny-mcp-authz-secret 2>/dev/null)
if [ -z "$SECRET" ]; then echo "  (overgeslagen: client secret niet leesbaar)"; else
  TOKEN=$(curl -sS -u "linny-mcp-authz:$SECRET" -d 'grant_type=client_credentials' \
    -H 'Host: auth.toorren.net' -H 'X-Forwarded-Proto: https' \
    "$AUTHELIA/api/oidc/token" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin).get("access_token",""))')
  if [ -z "$TOKEN" ]; then echo "  (overgeslagen: geen token gekregen)"; else
    ACTIVE=$(curl -sS -u "linny-mcp-authz:$SECRET" -d "token=$TOKEN" \
      -H 'Host: auth.toorren.net' -H 'X-Forwarded-Proto: https' \
      "$AUTHELIA/api/oidc/introspection" \
      | python3 -c 'import json,sys; print(json.load(sys.stdin).get("active"))')
    want True "$ACTIVE" "Authelia noemt het token geldig"
    want 401 "$(code -X POST -H "Authorization: Bearer $TOKEN" -d "$BODY" "$URL")" \
         "en tóch geweigerd (verkeerde client)"
  fi
fi

echo "backend-poorten niet van buiten bereikbaar"
for port in 8096 8097 9091; do
  if timeout 5 bash -c "echo > /dev/tcp/82.170.93.180/$port" 2>/dev/null; then
    want dicht bereikbaar "poort $port"
  else
    want dicht dicht "poort $port"
  fi
done

echo
if [ "$fails" -eq 0 ]; then echo "alle controles geslaagd"; else echo "$fails controle(s) gefaald"; fi
exit $((fails > 0))
