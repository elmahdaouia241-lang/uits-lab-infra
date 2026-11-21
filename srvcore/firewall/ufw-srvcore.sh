#!/usr/bin/env bash
# Pare-feu local UFW de srvcore : politique restrictive, seuls les services necessaires sont ouverts.
set -euo pipefail

sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Administration
sudo ufw allow from 192.168.10.0/24 to any port 22 proto tcp comment 'SSH admin'
sudo ufw allow from 192.168.20.0/24 to any port 22 proto tcp comment 'SSH serveurs (sauvegarde)'

# Services reseau
sudo ufw allow 53 comment 'DNS'
sudo ufw allow 67/udp comment 'DHCP server'
sudo ufw allow 68/udp comment 'DHCP client'
sudo ufw allow 123/udp comment 'NTP chrony'
sudo ufw allow from 192.168.10.0/24 to any port 3128 proto tcp comment 'Squid'
sudo ufw allow from 192.168.20.0/24 to any port 3128 proto tcp comment 'Squid'

# Messagerie et webmail
sudo ufw allow 25/tcp comment 'SMTP'
sudo ufw allow 143/tcp comment 'IMAP'
sudo ufw allow 587/tcp comment 'Submission'
sudo ufw allow 993/tcp comment 'IMAPS'
sudo ufw allow 80/tcp comment 'Webmail / Dashboard UITS'
sudo ufw allow 443/tcp comment 'HTTPS'

# Supervision : agent Zabbix (depuis srvzabbix) et Dashboard Suricata (depuis VLAN admin)
sudo ufw allow from 192.168.20.132 to any port 10050 proto tcp comment 'Zabbix agent'
sudo ufw allow from 192.168.10.0/24 to any port 5000 proto tcp comment 'Suricata dashboard'

sudo ufw logging on
sudo ufw --force enable
sudo ufw status verbose
