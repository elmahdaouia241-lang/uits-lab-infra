# Sécurité de l'infrastructure : menaces, contrôles et évolutions

## Modèle de menaces (simplifié)

| Menace | Scénario dans le lab | Contrôle | Où |
|---|---|---|---|
| Accès non autorisé aux serveurs | Un poste du VLAN utilisateurs essaie d'atteindre un serveur | Politiques FortiGate au moindre privilège, UFW sur chaque serveur | `gns3/configs/FortiGate.conf`, `srvcore/firewall/` |
| Déplacement latéral | Un serveur compromis attaque le VLAN d'administration | Politique 4 : VLAN 20 → VLAN 10 refusé et journalisé | `FortiGate.conf` |
| Reconnaissance réseau | Scan de ports, balayage ICMP | Règles Suricata 1000002 et 1000003, alertes sur dashboard | `srvcore/suricata/local.rules` |
| Force brute SSH | Tentatives de connexion répétées | Règle Suricata 1000001, SSH limité aux VLAN internes (UFW) | `local.rules`, `ufw-srvcore.sh` |
| Fuite de secrets | Jetons API, mots de passe dans un dépôt | Secrets en variables d'environnement, `.gitignore`, Gitleaks en CI | `glpi_alert.env.example`, `.github/workflows/ci.yml` |
| Perte de données | Panne ou suppression d'un serveur | Veeam Agent for Linux + rsync quotidien (00h30), rétention 7 jours | `srvbackup/` |
| Dérive de configuration / temps | Journaux illisibles, corrélation impossible | NTP centralisé (Chrony sur srvcore) | `srvcore/time/chrony.conf` |
| Indisponibilité non détectée | Un service tombe sans que personne le voie | Zabbix + alertes → ticket GLPI automatique | `srvzabbix/scripts/glpi_alert.sh` |

## Points de durcissement appliqués

- Politique UFW par défaut `deny incoming`, ouvertures nominatives et limitées par réseau source.
- DNS : récursion limitée aux réseaux internes (pas de résolveur ouvert).
- Squid : méthodes et ports restreints (`Safe_ports`), version et adresse client non divulguées.
- Postfix : relais interdit hors réseaux internes, authentification SASL via Dovecot.
- Dashboard Suricata : lecture seule du journal (unité systemd `ProtectSystem=strict`), exposé au seul VLAN d'administration.
- Sauvegardes par clés SSH (aucun mot de passe dans les scripts) et empreintes d'hôtes mémorisées (`accept-new`).
- Mots de passe par défaut (Zabbix `Admin/zabbix`, GLPI) à changer dès l'installation.

## Limites assumées

- Suricata fonctionne en **IDS** (détection), pas en IPS : il alerte, il ne bloque pas.
- Trafic interne en HTTP (lab) : prévoir TLS sur Zabbix, GLPI et le dashboard pour un environnement réel.
- Pas de centralisation des journaux (SIEM) : les alertes sont consultées sur le dashboard et dans Zabbix.

## Évolutions possibles

1. **Suricata en mode IPS** (NFQUEUE) sur un point de passage, ou réponse automatique via le FortiGate (liste d'adresses bloquées).
2. **SIEM** : envoi de `eve.json` vers Wazuh ou Elastic pour corrélation avec les journaux UFW et FortiGate.
3. **TLS** partout (certificats internes) et authentification forte (2FA GLPI, SSO).
4. **Infrastructure as Code** : Ansible pour appliquer les configurations de ce dépôt de façon reproductible.
5. **Sauvegardes testées** : restauration planifiée et vérifiée, copie hors site.
