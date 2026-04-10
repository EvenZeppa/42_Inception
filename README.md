# Inception

Projet Inception 42 realise par **ezeppa**.

## Objectif

Ce projet deploie une infra WordPress complete avec Docker Compose:

- Nginx (TLS)
- WordPress (PHP-FPM)
- MariaDB
- Bonus: Adminer, site statique, Redis, FTP

Le tout tourne sur un reseau Docker dedie avec persistance des donnees dans `/home/<login>/data`.

## Prerequis Linux

- Linux (VM 42 recommandee)
- Docker
- Docker Compose v2 (`docker compose`)
- `make`

Verifier rapidement:

```bash
docker --version
docker compose version
make --version
```

## Configuration

1. Generer le fichier d'environnement:

```bash
make env
```

2. Editer `srcs/.env` avec tes valeurs (exemple ezeppa):

```env
LOGIN_NAME=ezeppa
DOMAIN_NAME=ezeppa.42.fr
SITE_TITLE=Inception
DATA_DIR=/home/ezeppa/data
```

3. Creer les secrets localement (jamais commit):

```bash
mkdir -p secrets
printf '%s' 'change_me_db_password' > secrets/db_password.txt
printf '%s' 'change_me_db_root_password' > secrets/db_root_password.txt
printf '%s' 'change_me_wp_admin_password' > secrets/wp_admin_password.txt
printf '%s' 'change_me_wp_user_password' > secrets/wp_user_password.txt
printf '%s' 'change_me_ftp_password' > secrets/ftp_password.txt
chmod 600 secrets/*.txt
```

4. Ajouter le domaine dans `/etc/hosts`:

```bash
sudo nano /etc/hosts
```

Ajouter une ligne:

```text
127.0.0.1 ezeppa.42.fr
```

## Lancement

```bash
make up
```

Commandes utiles:

```bash
make ps
make logs
make down
make down-v
make reset
make re
```

## Acces

- Site WordPress: `https://ezeppa.42.fr`
- Admin WordPress: `https://ezeppa.42.fr/wp-admin`
- Adminer: `https://ezeppa.42.fr/adminer`
- Site statique: `https://ezeppa.42.fr/portfolio`

## Notes techniques

- Les volumes sont relies a `${DATA_DIR}/wordpress` et `${DATA_DIR}/mariadb`.
- Les mots de passe sont lus depuis `secrets/*.txt` via Docker secrets.
- Si les identifiants WordPress ne changent pas apres modification, vider les volumes avec `make down-v` puis relancer.

## Auteur

- ezeppa
