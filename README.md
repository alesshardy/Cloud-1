# Cloud-1 — Déploiement automatisé d'une stack WordPress sur AWS

Projet **Cloud-1** de l'école 42 : provisionner une infrastructure cloud et y déployer
une application web entièrement automatisée, reproductible et sécurisée — sans aucune
intervention manuelle sur le serveur.

Terraform crée le serveur sur **AWS**, Ansible s'y connecte en SSH pour installer Docker
et orchestrer une stack de conteneurs (**WordPress + MariaDB + phpMyAdmin + nginx**).
Le tout est **idempotent** (rejouable sans effet de bord) et les secrets sont **chiffrés**
dans le dépôt via `ansible-vault`.

---

## Architecture

```
┌──────────────┐        ┌──────────────────────── Instance AWS (Ubuntu) ───────────────────────┐
│  Terraform   │  crée  │                                                                        │
│  (infra)     │ ─────► │   ┌────────┐   docker-compose                                          │
└──────────────┘        │   │ nginx  │  reverse-proxy TLS (80 → redirect, 443 → HTTPS)           │
                        │   └───┬────┘                                                           │
┌──────────────┐  SSH   │       │                                                                │
│   Ansible    │ ─────► │   ┌───▼──────┐   ┌────────────┐   ┌──────────┐                         │
│  (config)    │        │   │ wordpress│   │ phpmyadmin │   │ mariadb  │ ◄── volumes persistés   │
└──────────────┘        │   └──────────┘   └────────────┘   └──────────┘                         │
                        └────────────────────────────────────────────────────────────────────────┘
```

Chaque service tourne dans **son propre conteneur** (1 process = 1 conteneur). nginx est
le seul point d'entrée exposé et termine le TLS ; WordPress et phpMyAdmin ne sont joignables
qu'à travers lui, sur un réseau Docker interne.

---

## Stack technique

| Couche            | Outil / Image            | Rôle                                                        |
|-------------------|--------------------------|-------------------------------------------------------------|
| Infrastructure    | **Terraform** (AWS)      | Instance EC2, Elastic IP, security group (firewall)         |
| Configuration     | **Ansible**              | Installation Docker, déploiement de la stack, install WP    |
| Reverse-proxy     | **nginx:alpine**         | Terminaison TLS, redirection HTTP → HTTPS                   |
| CMS               | **wordpress:latest**     | Le site, installé automatiquement via wp-cli                |
| Base de données   | **mariadb:10.6**         | Données WordPress, sur volume persistant                    |
| Administration BDD| **phpmyadmin**           | Interface web d'administration de la base                   |

---

## Points clés de sécurité

- **Secrets chiffrés** : `group_vars/all/vault.yml` est versionné chiffré (`ansible-vault`),
  sa clé n'est jamais dans le dépôt.
- **Mots de passe jamais en clair dans l'environnement** : MariaDB et WordPress lisent leurs
  mots de passe via des **Docker secrets** (fichiers montés dans `/run/secrets/`), pas via des
  variables d'environnement.
- **phpMyAdmin sans credentials embarqués** : l'utilisateur s'authentifie avec ses propres
  identifiants de base ; aucun secret n'est stocké dans le conteneur.
- **Firewall minimal** : seuls les ports nécessaires (SSH, HTTP, HTTPS) sont ouverts côté AWS.

---

## Organisation du dépôt

```
.
├── terraform/              # Provisionnement de l'infra AWS (instance, IP, firewall)
├── deploy.yml              # Playbook Ansible principal
├── ansible.cfg
├── inventory.ini.example   # Modèle d'inventaire (IP du serveur)
├── group_vars/all/
│   ├── vars.yml            # Variables non sensibles
│   └── vault.yml           # Secrets (chiffré avec ansible-vault)
└── roles/
    ├── common/             # Préparation du serveur (paquets, dossiers)
    ├── docker/             # Installation du moteur Docker
    ├── tls/                # Certificat TLS (Let's Encrypt / auto-signé)
    ├── deploy/             # docker-compose, nginx, .env → lancement de la stack
    └── wordpress/          # Installation automatique du site via wp-cli
```

Le déploiement se joue en 5 rôles Ansible successifs, chacun taggé pour pouvoir être
rejoué isolément.

---

## Idempotence & résilience

- Le playbook est **idempotent** : le rejouer ne déclenche aucun changement si l'état
  est déjà correct.
- Les données (base MariaDB, fichiers WordPress) sont stockées sur des **volumes Docker**,
  et les conteneurs redémarrent automatiquement (`restart: always`) : après un reboot du
  serveur, le site remonte seul avec toutes ses données.
