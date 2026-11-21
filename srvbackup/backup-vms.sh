#!/usr/bin/env bash
# /usr/local/bin/backup-vms.sh - sauvegarde rsync des serveurs du lab vers srvbackup (/srv/backup)
# Authentification par CLE SSH (aucun mot de passe dans le script) :
#   ssh-keygen -t ed25519 -f ~/.ssh/id_backup
#   ssh-copy-id -i ~/.ssh/id_backup.pub srvglpi@192.168.20.141   (idem srvzabbix, srvcore)
# Les comptes distants doivent pouvoir lire les dossiers sauvegardes (sudo rsync sans mot de passe
# pour la sauvegarde : voir README.md).
set -euo pipefail

DEST="/srv/backup"
DATE="$(date +%Y-%m-%d)"
KEEP_DAYS=7
KEY="${BACKUP_SSH_KEY:-$HOME/.ssh/id_backup}"
LOG="/var/log/backup-vms.log"

# nom : utilisateur@ip
declare -A HOSTS=(
  [glpi]="srvglpi@192.168.20.141"
  [zabbix]="srvzabbix@192.168.20.132"
  [core]="srvcore@192.168.20.133"
)
SOURCES=(/etc /var /home)

exec >>"$LOG" 2>&1
echo "=== Sauvegarde ${DATE} $(date +%T) ==="

for name in "${!HOSTS[@]}"; do
  mkdir -p "${DEST}/${name}/${DATE}"
  for src in "${SOURCES[@]}"; do
    # StrictHostKeyChecking=accept-new : empreinte memorisee a la 1re connexion, refusee si elle change
    rsync -az --delete-excluded --exclude='/var/cache' --exclude='/var/tmp' \
      -e "ssh -i ${KEY} -o StrictHostKeyChecking=accept-new" \
      "${HOSTS[$name]}:${src}" "${DEST}/${name}/${DATE}/" \
      && echo "OK   ${name}:${src}" || echo "FAIL ${name}:${src}"
  done
done

# Retention : suppression des sauvegardes de plus de KEEP_DAYS jours
find "$DEST" -mindepth 2 -maxdepth 2 -type d -mtime +"$KEEP_DAYS" -exec rm -rf {} +
echo "=== Fin $(date +%T) ==="
