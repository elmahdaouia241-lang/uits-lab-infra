#!/usr/bin/env bash
# /usr/lib/zabbix/alertscripts/glpi_alert.sh
# Cree un ticket d'incident GLPI a partir d'une alerte Zabbix (API REST GLPI).
#
# Parametres du Media Type Zabbix (type Script), dans cet ordre :
#   {ALERT.SUBJECT}  {ALERT.MESSAGE}  {EVENT.SEVERITY}
#
# Les jetons ne sont PAS dans le script : ils sont lus dans /etc/zabbix/glpi_alert.env
# (chmod 600, proprietaire zabbix) a partir du modele glpi_alert.env.example.
set -euo pipefail

SUBJECT="${1:-Alerte Zabbix}"
MESSAGE="${2:-}"
SEVERITY="${3:-Average}"

ENV_FILE="${GLPI_ENV_FILE:-/etc/zabbix/glpi_alert.env}"
# shellcheck disable=SC1090
source "$ENV_FILE"
: "${GLPI_URL:?}" "${APP_TOKEN:?}" "${USER_TOKEN:?}"

# Gravite Zabbix -> urgence GLPI (1 tres basse ... 5 majeure)
case "$SEVERITY" in
  Disaster)    URGENCY=5 ;;
  High)        URGENCY=4 ;;
  Average)     URGENCY=3 ;;
  Warning)     URGENCY=2 ;;
  *)           URGENCY=1 ;;
esac

SESSION="$(curl -s -m 15 -X GET "${GLPI_URL}/api.php/v1/initSession" \
  -H "Authorization: user_token ${USER_TOKEN}" \
  -H "App-Token: ${APP_TOKEN}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['session_token'])")"

# json.dumps echappe correctement le sujet et le message (guillemets, retours a la ligne...)
PAYLOAD="$(python3 - "$SUBJECT" "$MESSAGE" "$URGENCY" <<'PY'
import json, sys
subject, message, urgency = sys.argv[1], sys.argv[2], int(sys.argv[3])
print(json.dumps({"input": {"name": subject, "content": message,
                            "urgency": urgency, "priority": urgency, "type": 1}}))
PY
)"

curl -s -m 15 -X POST "${GLPI_URL}/api.php/v1/Ticket" \
  -H "Session-Token: ${SESSION}" \
  -H "App-Token: ${APP_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD"

# Fermeture de la session API
curl -s -m 15 -X GET "${GLPI_URL}/api.php/v1/killSession" \
  -H "Session-Token: ${SESSION}" -H "App-Token: ${APP_TOKEN}" >/dev/null
