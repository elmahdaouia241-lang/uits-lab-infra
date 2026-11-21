#!/usr/bin/env bash
# Declenche des alertes Suricata et verifie qu'elles apparaissent dans eve.json.
# A lancer sur srvcore (depuis srvcore, le trafic passe par l'interface surveillee).
set -uo pipefail
EVE=/var/log/suricata/eve.json
START="$(date +%s)"

echo "== 1/3 Regle Emerging Threats (test officiel OISF, signature GPL ATTACK_RESPONSE id check)"
curl -s -m 10 http://testmynids.org/uid/index.html >/dev/null || echo "   (pas d'acces Internet : test ignore)"

echo "== 2/3 Regle locale 1000002 : balayage ICMP"
ping -c 25 -i 0.2 127.0.0.1 >/dev/null 2>&1
ping -c 25 -i 0.2 192.168.20.254 >/dev/null 2>&1 || true

echo "== 3/3 Regle locale 1000003 : scan de ports SYN (necessite nmap : sudo apt install nmap)"
if command -v nmap >/dev/null; then nmap -sS -T4 -p 1-100 192.168.20.133 >/dev/null 2>&1; else echo "   nmap absent : test ignore"; fi

sleep 5
echo
echo "Alertes depuis le debut du test :"
jq -r --argjson t "$START" 'select(.event_type=="alert") | select((.timestamp|sub("\\.[0-9]+";"")|strptime("%Y-%m-%dT%H:%M:%S%z")|mktime) >= $t) | "\(.timestamp[0:19])  \(.alert.signature)  \(.src_ip)->\(.dest_ip)"' "$EVE" | tail -15
