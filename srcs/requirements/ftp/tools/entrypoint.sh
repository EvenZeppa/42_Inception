#!/bin/sh
set -e

# Créer l'utilisateur FTP avec UID 33 (www-data) pour accès au volume WordPress
if ! id ftpuser >/dev/null 2>&1; then
    useradd -o -u 33 -g 33 -d /var/www/html -s /usr/sbin/nologin -M ftpuser
fi

# Définir le mot de passe depuis le secret
if [ -f /run/secrets/ftp_password ]; then
    echo "ftpuser:$(cat /run/secrets/ftp_password)" | chpasswd
fi

# S'assurer que /var/www/html existe
mkdir -p /var/www/html

exec "$@"
