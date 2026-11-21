#!/usr/bin/env bash
# Valide l'infrastructure UITS lab.lan de bout en bout (connectivite, DNS, ports, services web, pare-feu).
# A lancer depuis un hote du VLAN 10 (ex. une VM d'administration) ou depuis srvcore.
#   ./scripts/validate-lab.sh            sortie 0 = tout est conforme, 1 = au moins un echec
# Adresses modifiables par variables d'environnement (plan d'adressage du depot par defaut).
set -uo pipefail

CORE="${CORE:-192.168.20.133}"
ZBX="${ZBX:-192.168.20.132}"
GLPI="${GLPI:-192.168.20.141}"
BCK="${BCK:-192.168.20.134}"
GW="${GW:-192.168.20.254}"

PASS=0; FAIL=0
ok()   { printf '  [OK]   %s\n' "$1"; PASS=$((PASS + 1)); }
ko()   { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }
check() { # check <description> <commande...>
  local d="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$d"; else ko "$d"; fi
}
refused() { # refused <description> <commande...> : succes si la commande ECHOUE
  local d="$1"; shift
  if "$@" >/dev/null 2>&1; then ko "$d (acces possible, devrait etre bloque)"; else ok "$d"; fi
}
tcp() { timeout 3 bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null; }

for bin in ping dig curl; do
  command -v "$bin" >/dev/null 2>&1 || { echo "Outil manquant : $bin" >&2; exit 2; }
done

echo "== Connectivite (ICMP)"
for h in "$GW" "$CORE" "$ZBX" "$GLPI" "$BCK"; do check "ping $h" ping -c 1 -W 2 "$h"; done

echo "== DNS (BIND9 sur srvcore)"
check "srvglpi.lab.lan -> $GLPI" bash -c "[ \"\$(dig +short +time=2 +tries=1 @$CORE srvglpi.lab.lan)\" = \"$GLPI\" ]"
check "srvzabbix.lab.lan -> $ZBX" bash -c "[ \"\$(dig +short +time=2 +tries=1 @$CORE srvzabbix.lab.lan)\" = \"$ZBX\" ]"
check "resolution inverse $CORE -> srvcore.lab.lan." bash -c "dig +short +time=2 +tries=1 @$CORE -x $CORE | grep -q 'srvcore.lab.lan'"
check "resolution externe (forwarders)" bash -c "[ -n \"\$(dig +short +time=3 +tries=1 @$CORE example.com)\" ]"

echo "== Ports de services (pare-feu UFW)"
for p in 22 53 25 143 3128 5000; do check "srvcore $p/tcp ouvert" tcp "$CORE" "$p"; done
check "srvzabbix 80/tcp (frontend)" tcp "$ZBX" 80
check "srvglpi 80/tcp (GLPI)" tcp "$GLPI" 80
check "srvbackup 22/tcp (SSH sauvegarde)" tcp "$BCK" 22
refused "srvcore 9999/tcp bloque par UFW" tcp "$CORE" 9999

echo "== Services web"
check "Zabbix frontend repond" bash -c "curl -s -o /dev/null -m 5 -w '%{http_code}' http://$ZBX/zabbix/ | grep -qE '^(200|302)$'"
check "GLPI repond" bash -c "curl -s -o /dev/null -m 5 -w '%{http_code}' http://$GLPI/ | grep -qE '^(200|301|302)$'"
check "Dashboard Suricata (JSON des alertes)" bash -c "curl -s -m 5 http://$CORE:5000/api/alerts | grep -q '^\['"

echo "== Segmentation (a lancer depuis le VLAN 10 : le VLAN 20 ne doit pas initier vers le VLAN 10)"
echo "  (test manuel : depuis srvglpi, 'ping 192.168.10.11' doit echouer - politique FortiGate 4)"

echo
echo "Resultat : ${PASS} OK, ${FAIL} echec(s)"
[ "$FAIL" -eq 0 ]
