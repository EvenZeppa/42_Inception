FROM debian:bookworm

RUN apt-get update \
    && apt-get install -y nginx \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/nginx/sites-enabled/default

COPY ./index.html /var/www/html/index.html
COPY ./style.css /var/www/html/style.css
COPY ./default.conf /etc/nginx/sites-available/default
RUN ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
