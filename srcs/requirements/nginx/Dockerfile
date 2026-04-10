FROM debian:bookworm

RUN apt -y update \
    && apt install -y nginx openssl \
    && rm /etc/nginx/sites-enabled/default \
    && rm /etc/nginx/sites-available/default \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/nginx/ssl

COPY ./conf/inception-site.conf /etc/nginx/sites-available/inception-site.conf.template
COPY ./tools/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
