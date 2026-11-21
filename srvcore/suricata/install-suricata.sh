#!/usr/bin/env bash
# Installe et configure Suricata IDS sur srvcore (Ubuntu Server 24.04).
# Usage : sudo ./install-suricata.sh [interface]      (defaut : ens33)
set -euo pipefail

IFACE="${1:-ens33}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ "$(id -u)" -eq 0 ] || { echo "Lancer avec sudo" >&2; exit 2; }
ip link show "$IFACE" >/dev/null 2>&1 || { echo "Interface $IFACE introuvable (ip -br link)" >&2; exit 2; }

echo "== 1/6 Installation (depot officiel OISF)"
apt-get update -y
apt-get install -y software-properties-common
add-apt-repository -y ppa:oisf/suricata-stable
apt-get update -y
apt-get install -y suricata jq python3-flask

echo "== 2/6 Configuration : interface ${IFACE}, reseaux proteges"
install -d /etc/suricata
cp -n /etc/suricata/suricata.yaml /etc/suricata/suricata.yaml.orig
# HOME_NET = reseaux du lab ; interface de capture AF_PACKET
sed -i -E 's|^( *HOME_NET:).*|\1 "[192.168.10.0/24,192.168.20.0/24]"|' /etc/suricata/suricata.yaml
sed -i -E "s|^( *- interface:) .*|\1 ${IFACE}|" /etc/suricata/suricata.yaml
# Le fichier suricata-overrides.yaml fixe cluster-id 99 / cluster_flow / defrag (voir le depot)
grep -q 'cluster-id: 99' /etc/suricata/suricata.yaml || \
  echo "!! Verifier la section af-packet de suricata.yaml (cluster-id: 99, cluster-type: cluster_flow, defrag: yes)"

echo "== 3/6 Regles : Emerging Threats Open + regles locales"
suricata-update update-sources
suricata-update enable-source et/open || true
install -m 0644 "${HERE}/local.rules" /var/lib/suricata/rules/local.rules
grep -q 'local.rules' /etc/suricata/suricata.yaml || \
  sed -i '/^rule-files:/a\  - local.rules' /etc/suricata/suricata.yaml
suricata-update

echo "== 4/6 Validation de la configuration"
suricata -T -c /etc/suricata/suricata.yaml -v

echo "== 5/6 Demarrage"
systemctl enable --now suricata
sleep 3
systemctl --no-pager --lines=5 status suricata

echo "== 6/6 Dashboard Flask (port 5000)"
install -d /opt/suricata-dashboard
install -m 0644 "${HERE}/dashboard/app.py" /opt/suricata-dashboard/app.py
install -m 0644 "${HERE}/dashboard/suricata-dashboard.service" /etc/systemd/system/suricata-dashboard.service
systemctl daemon-reload
systemctl enable --now suricata-dashboard

echo
echo "Regles chargees : $(grep -o '"rules_loaded":[0-9]*' /var/log/suricata/stats.log 2>/dev/null | tail -1 || echo 'voir suricata.log')"
echo "Dashboard : http://192.168.20.133:5000      Alertes : /var/log/suricata/eve.json"
echo "Test : ./test-ids.sh"
