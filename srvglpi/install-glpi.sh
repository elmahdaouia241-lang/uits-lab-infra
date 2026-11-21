#!/usr/bin/env bash
# Installe GLPI (Apache + PHP + MySQL) sur srvglpi, Ubuntu Server 24.04.
#   export GLPI_DB_PASSWORD='...'                       (genere : openssl rand -base64 24)
#   export GLPI_TARBALL_URL='https://github.com/glpi-project/glpi/releases/download/<version>/glpi-<version>.tgz'
#   sudo -E ./install-glpi.sh
# L'URL est a recuperer sur https://github.com/glpi-project/glpi/releases (GLPI 11 : API sur /api.php/v1).
set -euo pipefail

: "${GLPI_DB_PASSWORD:?Definir GLPI_DB_PASSWORD}"
: "${GLPI_TARBALL_URL:?Definir GLPI_TARBALL_URL (voir en-tete du script)}"
[ "$(id -u)" -eq 0 ] || { echo "Lancer avec sudo -E" >&2; exit 2; }

echo "== 1/4 Prerequis"
apt-get update -y
apt-get install -y apache2 mysql-server php php-mysql php-curl php-gd php-intl php-mbstring \
  php-xml php-zip php-bz2 php-ldap php-apcu php-opcache php-cli libapache2-mod-php

echo "== 2/4 Base de donnees"
systemctl enable --now mysql
mysql <<SQL
CREATE DATABASE IF NOT EXISTS glpi CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'glpi'@'localhost' IDENTIFIED BY '${GLPI_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON glpi.* TO 'glpi'@'localhost';
SQL
# GLPI exige l'acces aux fuseaux horaires MySQL
mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql mysql
mysql -e "GRANT SELECT ON mysql.time_zone_name TO 'glpi'@'localhost'; FLUSH PRIVILEGES;"

echo "== 3/4 Deploiement de GLPI"
cd /tmp
wget -q -O glpi.tgz "$GLPI_TARBALL_URL"
rm -rf /var/www/html/glpi
tar -xzf glpi.tgz -C /var/www/html
chown -R www-data:www-data /var/www/html/glpi

echo "== 4/4 Apache"
sed -i 's/^;\?session.cookie_httponly.*/session.cookie_httponly = On/' /etc/php/*/apache2/php.ini
systemctl restart apache2

echo
echo "Assistant d'installation : http://192.168.20.141/glpi  (base: glpi / utilisateur: glpi)."
echo "Puis : Configuration > General > API : activer l'API REST, creer APP/USER token,"
echo "restreindre l'acces a 192.168.20.132 (srvzabbix) et changer les mots de passe par defaut."
echo "Pare-feu : sudo ufw allow 22/tcp && sudo ufw allow 80/tcp && sudo ufw allow 443/tcp"
