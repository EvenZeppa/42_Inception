FROM debian:bookworm

# Installation de PHP et des dépendances
RUN apt update && apt install -y \
    php8.2-fpm \
    php8.2-mysqli \
    php8.2-curl \
    php8.2-dom \
    php8.2-exif \
    php8.2-fileinfo \
    php8.2-mbstring \
    php8.2-xml \
    php8.2-zip \
    php8.2-redis \
    mariadb-client \
    wget \
    netcat-traditional \
    && rm -rf /var/lib/apt/lists/*

# Installation de WP-CLI
RUN wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# Configuration de PHP-FPM (dossier run + pool config)
RUN mkdir -p /run/php
COPY ./conf/www.conf /etc/php/8.2/fpm/pool.d/

# Script d'entrée
COPY ./tools/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /var/www/html

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# -F pour forcer PHP-FPM à rester au premier plan
CMD ["php-fpm8.2", "-F"]
