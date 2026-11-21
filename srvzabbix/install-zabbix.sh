#!/usr/bin/env bash
# Installe Zabbix 7.0 (serveur + frontend Apache + MySQL) sur srvzabbix, Ubuntu Server 24.04.
# Le mot de passe de la base est fourni par variable d'environnement : jamais ecrit dans le depot.
#   export ZBX_DB_PASSWORD='...'   (genere ex. avec : openssl rand -base64 24)
#   sudo -E ./install-zabbix.sh
set -euo pipefail

: "${ZBX_DB_PASSWORD:?Definir ZBX_DB_PASSWORD avant de lancer le script}"
[ "$(id -u)" -eq 0 ] || { echo "Lancer avec sudo -E" >&2; exit 2; }

echo "== 1/5 Depot officiel Zabbix 7.0"
cd /tmp
wget -q https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb
dpkg -i zabbix-release_latest_7.0+ubuntu24.04_all.deb
apt-get update -y

echo "== 2/5 Paquets"
apt-get install -y mysql-server zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf \
  zabbix-sql-scripts zabbix-agent

echo "== 3/5 Base de donnees"
systemctl enable --now mysql
mysql <<SQL
CREATE DATABASE IF NOT EXISTS zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER IF NOT EXISTS 'zabbix'@'localhost' IDENTIFIED BY '${ZBX_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
SET GLOBAL log_bin_trust_function_creators = 1;
SQL
if [ "$(mysql -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='zabbix'")" -eq 0 ]; then
  zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -p"${ZBX_DB_PASSWORD}" zabbix
fi
mysql -e "SET GLOBAL log_bin_trust_function_creators = 0;"

echo "== 4/5 Configuration du serveur"
sed -i "s|^# DBPassword=.*|DBPassword=${ZBX_DB_PASSWORD}|; s|^DBPassword=.*|DBPassword=${ZBX_DB_PASSWORD}|" /etc/zabbix/zabbix_server.conf
chmod 640 /etc/zabbix/zabbix_server.conf
chown root:zabbix /etc/zabbix/zabbix_server.conf

echo "== 5/5 Demarrage"
systemctl enable --now zabbix-server zabbix-agent apache2
systemctl restart zabbix-server zabbix-agent apache2

echo
echo "Frontend : http://192.168.20.132/zabbix (assistant d'installation, langue/fuseau/base)."
echo "Ensuite : changer le mot de passe du compte Admin (par defaut Admin / zabbix)."
