# Cloud-1 — Déploiement automatisé d'Inception

Terraform provisionne un serveur vierge sur AWS, Ansible s'y connecte en SSH pour installer Docker et déployer une stack de 4 conteneurs via docker-compose, le tout automatisé, idempotent et avec des secrets chiffrés.

---

Déploie WordPress + MariaDB + phpMyAdmin + nginx (1 process = 1 conteneur) sur une
instance AWS, via **Terraform** (infra) et **Ansible** (config + Docker).

> Le vault `group_vars/all/vault.yml` est versionné **chiffré** (ansible-vault).
> Son mot de passe est fourni à l'oral, jamais dans le dépôt.

---

## Prérequis (machine de contrôle)

```bash
pipx install ansible            # ou : pip install --user ansible
pipx install awscli            # si provisioning AWS
# terraform : https://developer.hashicorp.com/terraform/install
aws configure                  # clé AWS + région eu-west-3
```
Aucune collection Ansible externe nécessaire (modules `ansible.builtin` uniquement).
Il faut aussi la clé SSH `~/.ssh/cloud1-paris.pem` (hors dépôt).

---

## Déploiement

```bash
# 1. Créer l'infra (instance + Elastic IP + firewall)
cd terraform
terraform init
terraform apply                # -> tape "yes"
terraform output server_ip     # note l'IP

# 2. Renseigner l'inventory avec cette IP
cd ..
cp inventory.ini.example inventory.ini
#   puis remplace X.X.X.X par l'IP (ou : sed -i 's/X.X.X.X/<IP>/' inventory.ini)

# 3. Déployer (mot de passe du vault demandé)
ansible-playbook deploy.yml --ask-vault-pass
```

Site : `https://<IP>`  ·  phpMyAdmin : `https://<IP>/phpmyadmin/`

---

## Commandes utiles (correction)

```bash
# Idempotence : relancer -> doit finir en changed=0
ansible-playbook deploy.yml --ask-vault-pass

# Déployer un rôle isolé
ansible-playbook deploy.yml --ask-vault-pass --tags docker   # ou tls / deploy / wordpress

# Voir / éditer les secrets chiffrés
ansible-vault view group_vars/all/vault.yml
ansible-vault edit group_vars/all/vault.yml

# Sur le serveur (via SSH)
ssh -i ~/.ssh/cloud1-paris.pem ubuntu@<IP>
cd /home/ubuntu/inception
sudo docker compose ps                 # état des conteneurs
sudo docker compose restart nginx      # redémarrer un conteneur
sudo docker volume ls                  # voir les volumes (données persistées)
sudo reboot                            # test persistance : le site remonte seul
```

---

## Nettoyage (après la soutenance)

```bash
cd terraform
terraform destroy                      # supprime tout -> plus de facturation
```
