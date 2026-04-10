#!/bin/bash

read_secret() {
  local var_name="$1"
  local file_var_name="${var_name}_FILE"
  local file_path="${!file_var_name:-}"
  if [ -n "${file_path}" ] && [ -f "${file_path}" ]; then
    export "${var_name}=$(cat "${file_path}")"
  fi
}

read_secret "SQL_PASSWORD"
read_secret "SQL_ROOT_PASSWORD"

# Si déjà configuré ET tables système présentes -> skip setup
if [ -f "/var/lib/mysql/.inception_configured" ] && { [ -f "/var/lib/mysql/mysql/db.ibd" ] || [ -f "/var/lib/mysql/mysql/db.frm" ]; }; then
  exec "$@"
fi
# Données corrompues (mysql.db manquant) -> on force la réinit
if [ -f "/var/lib/mysql/.inception_configured" ]; then
  rm -f /var/lib/mysql/.inception_configured
fi

if [ -z "${SQL_DATABASE}" ] || [ -z "${SQL_USER}" ] || [ -z "${SQL_PASSWORD}" ] || [ -z "${SQL_ROOT_PASSWORD}" ]; then
  echo "Variables manquantes: SQL_DATABASE/SQL_USER/SQL_PASSWORD/SQL_ROOT_PASSWORD"
  exit 1
fi

SOCKET="/run/mysqld/mysqld.sock"
mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld

DEBIAN_USER=""
DEBIAN_PASS=""
if [ -f /etc/mysql/debian.cnf ]; then
  DEBIAN_USER="$(grep -m1 '^user=' /etc/mysql/debian.cnf | cut -d= -f2- | tr -d '[:space:]' || true)"
  DEBIAN_PASS="$(grep -m1 '^password=' /etc/mysql/debian.cnf | cut -d= -f2- | tr -d '[:space:]' || true)"
fi

# 1. Crée les fichiers système de MariaDB (tables mysql.db, etc.)
#    Sur macOS (bind mount), des données partielles/corrompues peuvent exister.
#    Si mysql/ n'existe pas ou est incomplet, on nettoie et réinitialise.
if [ ! -f "/var/lib/mysql/mysql/db.ibd" ] && [ ! -f "/var/lib/mysql/mysql/db.frm" ]; then
    echo "Initialisation du répertoire des données MariaDB..."
    rm -rf /var/lib/mysql/*
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql 2>/dev/null || \
    mysql_install_db --user=mysql --datadir=/var/lib/mysql
    chown -R mysql:mysql /var/lib/mysql
fi

# 2. On lance MariaDB en arrière-plan (le & à la fin).
#    Pour configurer des utilisateurs avec la commande mysql -e, le serveur doit être en train de tourner. 
#    On le lance donc temporairement juste pour la configuration
mysqld_safe --user=mysql --datadir='/var/lib/mysql' --skip-networking --socket="${SOCKET}" &
MYSQLD_SAFE_PID="$!"

# 3. Attendre que MariaDB réponde vraiment 
#    Le processus MariaDB peut prendre quelques secondes à s'initialiser. 
#    Si on essaie de créer l'utilisateur trop tôt, la commande échouera car le serveur ne répondra pas encore.
MAX_TRIES=30
tries=0
until mysqladmin --protocol=socket --socket="${SOCKET}" ping >/dev/null 2>&1; do
    tries=$((tries + 1))
    if [ "${tries}" -ge "${MAX_TRIES}" ]; then
        echo "MariaDB ne répond pas après ${MAX_TRIES} tentatives, arrêt."
        exit 1
    fi
    echo "En attente de MariaDB..."
    sleep 5
done

mysql_exec() {
  local query="$1"
  if mysql --protocol=socket --socket="${SOCKET}" -uroot -e "${query}" >/dev/null 2>&1; then
    mysql --protocol=socket --socket="${SOCKET}" -uroot -e "${query}"
    return 0
  fi
  if mysql --protocol=socket --socket="${SOCKET}" -uroot -p"${SQL_ROOT_PASSWORD}" -e "${query}" >/dev/null 2>&1; then
    mysql --protocol=socket --socket="${SOCKET}" -uroot -p"${SQL_ROOT_PASSWORD}" -e "${query}"
    return 0
  fi
  if [ -n "${DEBIAN_USER}" ] && [ -n "${DEBIAN_PASS}" ] && mysql --protocol=socket --socket="${SOCKET}" -u"${DEBIAN_USER}" -p"${DEBIAN_PASS}" -e "${query}" >/dev/null 2>&1; then
    mysql --protocol=socket --socket="${SOCKET}" -u"${DEBIAN_USER}" -p"${DEBIAN_PASS}" -e "${query}"
    return 0
  fi
  echo "Commande SQL échouée"
  return 1
}

# 4. Configuration SQL
#    On injecte les commandes SQL pour créer la base WordPress, mon utilisateur, 
#    et on sécurise le compte root avec le mot de passe de mon .env.
#    FLUSH PRIVILEGES; : Dit à MariaDB de recharger les tables de permissions pour appliquer les changements immédiatement.
if ! mysql_exec "SELECT 1;"; then
  echo "Root inaccessible avec les identifiants fournis, tentative de récupération..."
  pkill -TERM mariadbd 2>/dev/null || true
  pkill -TERM mysqld 2>/dev/null || true
  sleep 2
  mysqld_safe --user=mysql --datadir='/var/lib/mysql' --skip-networking --skip-grant-tables --socket="${SOCKET}" &
  tries=0
  until mysqladmin --protocol=socket --socket="${SOCKET}" ping >/dev/null 2>&1; do
      tries=$((tries + 1))
      if [ "${tries}" -ge "${MAX_TRIES}" ]; then
          echo "MariaDB (recovery) ne répond pas, arrêt."
          exit 1
      fi
      sleep 2
  done
  mysql --protocol=socket --socket="${SOCKET}" -uroot -e "FLUSH PRIVILEGES; ALTER USER 'root'@'localhost' IDENTIFIED BY '${SQL_ROOT_PASSWORD}'; FLUSH PRIVILEGES;"
  mysqladmin --protocol=socket --socket="${SOCKET}" -uroot shutdown || true
  sleep 2
  mysqld_safe --user=mysql --datadir='/var/lib/mysql' --skip-networking --socket="${SOCKET}" &
  tries=0
  until mysqladmin --protocol=socket --socket="${SOCKET}" ping >/dev/null 2>&1; do
      tries=$((tries + 1))
      if [ "${tries}" -ge "${MAX_TRIES}" ]; then
          echo "MariaDB (post-recovery) ne répond pas, arrêt."
          exit 1
      fi
      sleep 2
  done
fi

mysql_exec "CREATE DATABASE IF NOT EXISTS \`${SQL_DATABASE}\`;" || true
mysql_exec "CREATE USER IF NOT EXISTS \`${SQL_USER}\`@'%' IDENTIFIED BY '${SQL_PASSWORD}';" || true
mysql_exec "ALTER USER \`${SQL_USER}\`@'%' IDENTIFIED BY '${SQL_PASSWORD}';" || true
mysql_exec "GRANT ALL PRIVILEGES ON \`${SQL_DATABASE}\`.* TO \`${SQL_USER}\`@'%';" || true
mysql_exec "ALTER USER 'root'@'localhost' IDENTIFIED BY '${SQL_ROOT_PASSWORD}';" || true
mysql_exec "GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;" || true
# root@'%' for Adminer (connections from other containers)
mysql_exec "CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '${SQL_ROOT_PASSWORD}';" || true
mysql_exec "ALTER USER 'root'@'%' IDENTIFIED BY '${SQL_ROOT_PASSWORD}';" || true
mysql_exec "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;" || true
mysql_exec "FLUSH PRIVILEGES;" || true

# 5. Éteindre proprement pour relancer au premier plan
#    Un conteneur Docker doit avoir un seul processus principal au premier plan. 
#    On éteint donc la version "fantôme" qu'on a lancée à l'étape 2.
#    On utilise maintenant -p${SQL_ROOT_PASSWORD} car le mot de passe root vient d'être activé à l'étape précédente.
if mysqladmin --protocol=socket --socket="${SOCKET}" -u root shutdown >/dev/null 2>&1; then
  mysqladmin --protocol=socket --socket="${SOCKET}" -u root shutdown || true
elif mysqladmin --protocol=socket --socket="${SOCKET}" -u root -p"${SQL_ROOT_PASSWORD}" shutdown >/dev/null 2>&1; then
  mysqladmin --protocol=socket --socket="${SOCKET}" -u root -p"${SQL_ROOT_PASSWORD}" shutdown || true
elif [ -n "${DEBIAN_USER}" ] && [ -n "${DEBIAN_PASS}" ] && mysqladmin --protocol=socket --socket="${SOCKET}" -u "${DEBIAN_USER}" -p"${DEBIAN_PASS}" shutdown >/dev/null 2>&1; then
  mysqladmin --protocol=socket --socket="${SOCKET}" -u "${DEBIAN_USER}" -p"${DEBIAN_PASS}" shutdown || true
else
  kill -TERM "${MYSQLD_SAFE_PID}" 2>/dev/null || true
  pkill -TERM mariadbd 2>/dev/null || true
  pkill -TERM mysqld 2>/dev/null || true
fi

sleep 2

touch /var/lib/mysql/.inception_configured

# 6. Lancer le processus final (CMD)
#    exec remplace le script shell par la commande définie dans le CMD de mon Dockerfile (mysqld ...).
#    MariaDB se relance, mais cette fois-ci au premier plan. C'est ce processus qui gardera mon conteneur en vie. 
#    Si ce processus s'arrête, le conteneur s'arrête.
exec "$@"
