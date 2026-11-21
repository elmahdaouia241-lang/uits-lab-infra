# Ordre de déploiement et validation

## 0. Prérequis

- GNS3 2.2 + GNS3 VM (VMware), images : IOSv, IOSvL2, FortiGate 7.0.
- VMware Workstation 17 : 4 VM Ubuntu Server 24.04 (`srvcore`, `srvzabbix`, `srvglpi`, `srvbackup`), interface `ens33`.
- Projet GNS3 `test` : NAT1 → Router-1 → FortiGate → Switch-1 (VLAN 10) et Switch-2 (VLAN 20) ; Cloud1 (VMnet8 = 192.168.20.1/24) sur FortiGate port2.

## 1. Réseau GNS3

| Étape | Fichier | Console |
|---|---|---|
| Routeur | `gns3/configs/Router-1.cfg` | telnet Router-1 |
| Switches | `gns3/configs/Switch-1.cfg`, `Switch-2.cfg` | telnet Switch-1 / Switch-2 |
| Pare-feu | `gns3/configs/FortiGate.conf` (définir d'abord un mot de passe admin) | telnet FortiGate |
| Postes VLAN 10 | `gns3/vpcs/*.vpc` | `ip ...` dans chaque VPCS |

Validation : `ping 192.168.10.254` depuis `admin`, `show ip route` sur Router-1, `get router info routing-table all` sur FortiGate.

## 2. Serveurs (dans cet ordre)

1. **srvcore** : `network/50-srvcore.yaml` → `dns/` → `dhcp/` → `proxy/` → `mail/` → `time/` → `firewall/ufw-srvcore.sh`.
2. Autres serveurs : IP statique (192.168.20.132 / .141 / .134, passerelle .254, DNS 192.168.20.133).
3. **srvzabbix** : `ZBX_DB_PASSWORD=... sudo -E srvzabbix/install-zabbix.sh`, puis agents sur les 4 serveurs (`zabbix_agentd.conf.template`).
4. **srvglpi** : `srvglpi/install-glpi.sh`, activer l'API REST, créer les jetons.
5. **Intégration** : `srvzabbix/scripts/glpi_alert.sh` + `glpi_alert.env` (voir modèle), Media Type « GLPI » (type Script, paramètres `{ALERT.SUBJECT}`, `{ALERT.MESSAGE}`, `{EVENT.SEVERITY}` dans cet ordre).
6. **srvbackup** : clés SSH, `backup-vms.sh`, `crontab.txt` ; Veeam Agent for Linux (job « Backup-Infrastructure », 00h30).
7. **Suricata** : `sudo srvcore/suricata/install-suricata.sh`.

## 3. Suricata : validation

```bash
sudo suricata -T -c /etc/suricata/suricata.yaml -v   # configuration valide
sudo systemctl status suricata suricata-dashboard
./srvcore/suricata/test-ids.sh                      # déclenche alertes ET + règles locales
curl -s http://192.168.20.133:5000/api/alerts | jq   # depuis le VLAN admin
```

Intégration Zabbix : copier `srvcore/zabbix-agent/suricata.conf` dans `/etc/zabbix/zabbix_agentd.d/`, redémarrer l'agent,
créer un item `suricata.alerts.5m` et un trigger (> 10 alertes/5 min → sévérité High → ticket GLPI automatique).

## 4. Tests de bout en bout

| Test | Attendu |
|---|---|
| `admin` → `ping 192.168.20.133` | Réponse (politique 1) |
| `srvglpi` → `ping 192.168.10.11` | Bloqué (politique 4) |
| `nslookup srvglpi.lab.lan 192.168.20.133` | 192.168.20.141 |
| Arrêt de l'agent Zabbix sur srvglpi | Alerte Zabbix puis ticket GLPI créé |
| `test-ids.sh` | Alertes dans `eve.json` et sur le dashboard |
| `/usr/local/bin/backup-vms.sh` | Dossier daté dans `/srv/backup`, `OK` dans `/var/log/backup-vms.log` |

## 5. Limites connues

- **SPAN sur IOSvL2** : non garanti ; sans miroir, Suricata analyse le trafic de srvcore (rôle « IDS hôte »).
- **FortiGate évaluation** : licence d'essai limitée (débit, fonctions) : suffisante pour le lab.
- **Adressage** : plan du rapport (192.168.20.0/24). Si VMnet8 utilise un autre sous-réseau, adapter les fichiers (recherche globale de `192.168.20.`).
