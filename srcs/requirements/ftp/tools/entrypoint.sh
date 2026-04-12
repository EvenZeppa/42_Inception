#!/bin/sh
set -e

# Créer l'utilisateur FTP avec UID 33 (www-data) pour accès au volume WordPress
if ! id ftpuser >/dev/null 2>&1; then
    useradd -o -u 33 -g 33 -d /var/www/html -s /bin/bash -M -K UID_MIN=0 ftpuser
else
    usermod -d /var/www/html -s /bin/bash ftpuser
fi

# Définir le mot de passe depuis le secret
if [ -f /run/secrets/ftp_password ]; then
    FTP_PASSWORD="$(tr -d '\r\n' < /run/secrets/ftp_password)"
    echo "ftpuser:${FTP_PASSWORD}" | chpasswd
fi

# S'assurer que /var/www/html existe
mkdir -p /var/www/html

# vsftpd requires a non-writable secure chroot directory.
mkdir -p /var/run/vsftpd/empty
chmod 555 /var/run/vsftpd/empty

exec "$@"
