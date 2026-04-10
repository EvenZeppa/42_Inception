FROM debian:bookworm

RUN apt update
RUN apt install -y mariadb-server \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/mysqld && \
    chown -R mysql:mysql /var/run/mysqld && \
    chmod 777 /var/run/mysqld && \
    chown -R mysql:mysql /var/lib/mysql

COPY ./tools/setup.sh /usr/local/bin/setup.sh
RUN chmod +x /usr/local/bin/setup.sh

ENTRYPOINT ["/usr/local/bin/setup.sh"]

CMD ["mysqld", "--bind-address=0.0.0.0", "--user=mysql"]
