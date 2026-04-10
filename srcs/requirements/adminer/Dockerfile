FROM debian:bookworm

RUN apt-get update \
    && apt-get install -y php php-mysql wget \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/www/html

# Download Adminer (MySQL/English - lightweight)
RUN wget -q -O /var/www/html/index.php \
    "https://github.com/vrana/adminer/releases/download/v4.8.1/adminer-4.8.1-mysql-en.php"

WORKDIR /var/www/html

EXPOSE 8080

# Single process: PHP built-in server (no background processes)
CMD ["php", "-S", "0.0.0.0:8080"]
