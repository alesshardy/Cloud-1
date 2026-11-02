# Cloud-1 — Déploiement automatisé d'Inception

Déploiement automatisé d'une infrastructure WordPress (WordPress + MariaDB + phpMyAdmin
+ reverse-proxy nginx) sur une instance cloud, via **Terraform** (provisioning) et
**Ansible** (configuration + déploiement Docker).

> 1 process = 1 conteneur. Tout est automatisé : `terraform apply` crée le serveur,
> `ansible-playbook` installe Docker et lance la stack.

---

## Architecture

```
                 Internet
                    │  80 / 443 uniquement
                    ▼
        ┌───────────────────────┐
        │   nginx (reverse-proxy)│  TLS, redirige selon l'URL
        └───────────┬───────────┘
            /        │        /phpmyadmin/
            ▼        │             ▼
   ┌─────────────┐   │      ┌──────────────┐
   │  wordpress  │   │      │  phpmyadmin  │
   └──────┬──────┘   │      └──────┬───────┘
          │          │             │
          ▼          ▼             ▼
        ┌───────────────────────────┐
        │     db (MariaDB)          │  accessible uniquement en interne
        └───────────────────────────┘
          réseau Docker : wp_network
          volumes : db_data, wp_data
```

Seuls les ports **80** (redirigé vers 443) et **443** sont exposés. La base de données
n'a aucun port publié : elle n'est joignable que par les autres conteneurs sur le
réseau interne `wp_network`.

---

## Structure du dépôt

```
deploy.yml                     Playbook principal (orchestre les rôles)
ansible.cfg                    Config Ansible
inventory.ini.example          Modèle d'inventory (à copier)
group_vars/all/
  ├── vars.yml                 Variables non sensibles
  ├── vault.yml                SECRETS — gitignoré, à créer
  └── vault.yml.example        Modèle de secrets
roles/
  ├── common/                  Prépa serveur (apt, dépendances, dossiers)
  ├── docker/                  Installation du moteur Docker
  ├── certs/                   Génération du certificat TLS auto-signé
  └── deploy/                  Fichiers de conf + lancement de la stack
      ├── files/docker-compose.yml
      ├── files/nginx.conf
      └── templates/env.j2     Génère le .env sur le serveur
terraform/
  ├── main.tf                  Instance EC2 + security group + Elastic IP
  └── billing.tf               Alerte budget
```

---

## Prérequis

Sur votre machine :

- **Terraform** ≥ 1.2
- **Ansible** (`pip install --user ansible` ou `pipx install ansible`)
- **AWS CLI** configuré (`aws configure`) avec des identifiants valides
- Une **clé SSH** importée dans AWS (ici nommée `cloud1-paris`)

Sur l'instance cible : Ubuntu 20.04+ avec un démon SSH et Python (cas par défaut des AMI Ubuntu).

---

## Déploiement — pas à pas

### 1. Provisionner le serveur (Terraform)

```bash
cd terraform
terraform init
terraform apply          # crée l'instance EC2 + l'Elastic IP (IP publique fixe)
```

Récupérer l'IP publique affichée :

```bash
terraform output server_ip
```

> L'**Elastic IP** garantit que cette adresse ne change pas, même après un stop/start
> de l'instance. Plus besoin de reconfigurer quoi que ce soit entre deux sessions.

### 2. Configurer l'inventory

```bash
cd ..
cp inventory.ini.example inventory.ini
```

Éditer `inventory.ini` avec l'IP obtenue et le chemin vers votre clé SSH :

```ini
[webservers]
13.39.22.66 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/cloud1-paris.pem
```

### 3. Configurer les secrets

```bash
cp group_vars/all/vault.yml.example group_vars/all/vault.yml
```

Renseigner les mots de passe dans `group_vars/all/vault.yml`, puis (recommandé) le chiffrer :

```bash
ansible-vault encrypt group_vars/all/vault.yml
```

> `vault.yml` est **gitignoré** : aucun secret n'est versionné. Le `.env` utilisé par
> Docker est **généré** sur le serveur par Ansible à partir de ces variables.
> `DOMAIN_NAME` est renseigné automatiquement avec l'IP de l'inventory.

### 4. Lancer le déploiement

```bash
ansible-playbook deploy.yml
```

(si le vault est chiffré : `ansible-playbook deploy.yml --ask-vault-pass`)

Le site est accessible sur `https://<IP>` (certificat auto-signé → avertissement
navigateur normal) et phpMyAdmin sur `https://<IP>/phpmyadmin/`.

---

## Commandes utiles

### Déployer une partie seulement (rôles indépendants via tags)

```bash
ansible-playbook deploy.yml --tags docker     # juste l'installation Docker
ansible-playbook deploy.yml --tags certs      # juste le certificat TLS
ansible-playbook deploy.yml --tags deploy     # juste (re)déployer la stack
```

### Gérer les conteneurs (sur le serveur)

```bash
cd /home/ubuntu/inception
docker compose up -d              # tout lancer d'un coup
docker compose restart nginx      # redémarrer un conteneur individuellement
docker compose ps                 # état des conteneurs
docker volume ls                  # voir les volumes
docker volume inspect inception_db_data   # inspecter un volume
```

### Idempotence

Rejouer `ansible-playbook deploy.yml` plusieurs fois donne le même résultat sans casser
le site (installation Docker et génération du certificat protégées par `creates:`,
`docker compose up -d` ne recrée que ce qui a changé).

---

## Persistance & redémarrage

- `restart: always` sur chaque service + service Docker activé (`enabled: yes`) :
  les conteneurs redémarrent automatiquement après un reboot du serveur.
- Les volumes `db_data` (base) et `wp_data` (fichiers WordPress) persistent les
  données (articles, comptes, médias) à travers les redémarrages.

---

## Sécurité

- Seuls les ports 22 (SSH), 80 et 443 sont ouverts (security group Terraform).
- La base de données n'est pas exposée publiquement (aucun port publié).
- Aucun secret dans le dépôt : `.env`, `inventory.ini` et `vault.yml` sont gitignorés.
- TLS activé (certificat auto-signé), HTTP redirigé vers HTTPS.

---

## Nettoyage (après la soutenance)

Pour tout détruire et ne plus être facturé :

```bash
cd terraform
terraform destroy
```
