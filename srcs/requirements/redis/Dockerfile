FROM debian:bookworm

RUN apt-get update \
    && apt-get install -y redis-server \
    && rm -rf /var/lib/apt/lists/*

# Redis en mode foreground (pas de démon)
RUN sed -i 's/^supervised no/supervised no/' /etc/redis/redis.conf \
    && echo "bind 0.0.0.0" >> /etc/redis/redis.conf

EXPOSE 6379

CMD ["redis-server", "--bind", "0.0.0.0"]
