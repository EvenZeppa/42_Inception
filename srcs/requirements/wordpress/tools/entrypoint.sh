#!/bin/sh
set -e

read_secret() {
  var_name="$1"
  file_var_name="${var_name}_FILE"
  eval file_path="\${${file_var_name}:-}"
  if [ -n "${file_path}" ]; then
    if [ ! -f "${file_path}" ]; then
      echo "${file_path} introuvable"
      exit 1
    fi
    eval "${var_name}=\"$(cat "${file_path}")\""
    export "${var_name}"
    return
  fi
}

read_secret "SQL_PASSWORD"
read_secret "ADMIN_PASSWORD"
read_secret "USER_PASS"

require_var() {
  var_name="$1"
  eval val="\${${var_name}:-}"
  if [ -z "${val}" ]; then
    echo "${var_name} manquant"
    exit 1
  fi
}

require_var "SQL_DATABASE"
require_var "SQL_USER"
require_var "SQL_PASSWORD"
require_var "DOMAIN_NAME"
require_var "SITE_TITLE"
require_var "ADMIN_USER"
require_var "ADMIN_PASSWORD"
require_var "ADMIN_EMAIL"
require_var "USER_LOGIN"
require_var "USER_PASS"
require_var "USER_EMAIL"

echo "${ADMIN_USER}" | grep -qi "admin" && { echo "ADMIN_USER invalide"; exit 1; }
echo "${USER_LOGIN}" | grep -qi "admin" && { echo "USER_LOGIN invalide"; exit 1; }
if [ "${ADMIN_USER}" = "${USER_LOGIN}" ]; then
  echo "ADMIN_USER et USER_LOGIN doivent être différents"
  exit 1
fi

# 1. Attente de MariaDB
#    Docker lance les conteneurs presque en même temps. 
#	 WordPress démarre souvent avant que MariaDB n'ait fini d'initialiser ses bases.
#    nc (Netcat) interroge le port 3306 de l'hôte mariadb. Tant que le port est fermé, le script boucle. 
#	 Cela évite l'erreur fatale "Error establishing a database connection" au démarrage.
MAX_TRIES=60
tries=0
until nc -z mariadb 3306; do
    tries=$((tries + 1))
    if [ "${tries}" -ge "${MAX_TRIES}" ]; then
        echo "MariaDB n'est pas joignable après ${MAX_TRIES} tentatives, arrêt."
        exit 1
    fi
    echo "Le port 3306 de MariaDB est fermé - attente..."
    sleep 2
done
echo "Le port 3306 est ouvert !"

# Attente Redis (bonus)
tries=0
until nc -z redis 6379 2>/dev/null; do
    tries=$((tries + 1))
    if [ "${tries}" -ge 10 ]; then break; fi
    sleep 1
done
[ "${tries}" -lt 10 ] && echo "Redis prêt !" || echo "Redis non disponible, cache désactivé"

cd /var/www/html

# 2. Téléchargement des sources
#    On vérifie si index.php existe. Si non, on télécharge WordPress.
#	 --allow-root : WP-CLI refuse par défaut de s'exécuter en tant qu'utilisateur root. 
#    On le force ici car le conteneur tourne en root.
if [ ! -f index.php ]; then
    wp core download --allow-root
fi

if [ ! -f "wp-config.php" ]; then

# 3. Création du fichier wp-config.php
#    Il utilise mes variables d'environnement pour lier WordPress à ma base MariaDB.
#	 Cette commande génère automatiquement les "Salts" (clés de hachage uniques) dans le fichier, ce qui est une exigence de sécurité.
    wp config create \
        --dbname=$SQL_DATABASE \
        --dbuser=$SQL_USER \
        --dbpass=$SQL_PASSWORD \
        --dbhost=mariadb \
        --allow-root

# 4. Injection de PHP personnalisé
#    FS_METHOD : Permet d'installer des plugins ou thèmes sans que WordPress demande un accès FTP (très utile dans Docker).
#	 Indispensable car on utilises Nginx comme proxy SSL. 
#	 Ce code dit à WordPress : "Si le trafic arrive en HTTPS via le proxy, considère que le site est bien en HTTPS". 
#	 Sans ça, on risques des boucles de redirection infinies.
    wp config set FS_METHOD 'direct' --allow-root
    cat <<EOF >> wp-config.php
if (isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) && \$_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    \$_SERVER['HTTPS'] = 'on';
}
define('WP_REDIS_HOST', 'redis');
define('WP_REDIS_PORT', 6379);
EOF

# 5. Installation et création d'utilisateurs
#    core install : Remplit les tables de la base de données et crée le compte Administrateur.
#	 user create : Crée le second utilisateur (rôle author).
    wp core install \
        --url=$DOMAIN_NAME \
        --title=$SITE_TITLE \
        --admin_user=$ADMIN_USER \
        --admin_password=$ADMIN_PASSWORD \
        --admin_email=$ADMIN_EMAIL \
        --allow-root

    wp user create $USER_LOGIN $USER_EMAIL --role=author --user_pass=$USER_PASS --allow-root
    # Bonus: Redis Object Cache plugin
    wp plugin install redis-cache --activate --allow-root 2>/dev/null || true
fi

if wp core is-installed --allow-root >/dev/null 2>&1; then
    existing_id="$(wp user list --search="$ADMIN_EMAIL" --search-columns=user_email --field=ID --allow-root 2>/dev/null | head -n 1 || true)"
    if [ -n "${existing_id}" ]; then
        existing_login="$(wp user get "${existing_id}" --field=user_login --allow-root 2>/dev/null || true)"
        if [ -n "${existing_login}" ] && [ "${existing_login}" != "${ADMIN_USER}" ]; then
            wp user update "${existing_id}" --user_email="replaced-${existing_id}@local.invalid" --allow-root >/dev/null 2>&1 || true
        fi
    fi

    if wp user get "$ADMIN_USER" --field=ID --allow-root >/dev/null 2>&1; then
        wp user update "$ADMIN_USER" --user_pass="$ADMIN_PASSWORD" --user_email="$ADMIN_EMAIL" --role=administrator --skip-email --allow-root
    else
        wp user create "$ADMIN_USER" "$ADMIN_EMAIL" --role=administrator --user_pass="$ADMIN_PASSWORD" --skip-email --allow-root
    fi

    if wp user get "$USER_LOGIN" --field=ID --allow-root >/dev/null 2>&1; then
        wp user update "$USER_LOGIN" --user_pass="$USER_PASS" --user_email="$USER_EMAIL" --role=author --skip-email --allow-root
    else
        wp user create "$USER_LOGIN" "$USER_EMAIL" --role=author --user_pass="$USER_PASS" --skip-email --allow-root
    fi

    if [ "$ADMIN_USER" != "admin_login" ] && wp user get admin_login --field=ID --allow-root >/dev/null 2>&1; then
        admin_id="$(wp user get "$ADMIN_USER" --field=ID --allow-root)"
        wp user delete admin_login --reassign="${admin_id}" --yes --allow-root
    fi
    # Bonus: activer Redis si plugin présent
    wp plugin is-installed redis-cache --allow-root 2>/dev/null && wp plugin activate redis-cache --allow-root 2>/dev/null || true
fi

# 6. Permissions et lancement final
#    chown : Donne la propriété des fichiers à www-data (l'utilisateur standard pour PHP-FPM). 
#	 Sans ça, WordPress ne pourra pas uploader d'images ou faire des mises à jour.
#	 exec "$@" : Elle remplace le script par le processus principal défini dans mon Dockerfile (php-fpm8.2 -F). 
#	 Cela permet au conteneur de rester vivant et de recevoir les signaux d'arrêt correctement.
chown -R www-data:www-data /var/www/html/
exec "$@"
