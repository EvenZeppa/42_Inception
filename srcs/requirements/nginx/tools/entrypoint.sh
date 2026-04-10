#!/bin/sh
set -e

if [ -z "${DOMAIN_NAME}" ]; then
  echo "DOMAIN_NAME is not set"
  exit 1
fi

CERT_DIR="/etc/nginx/ssl"
CERT_CRT="${CERT_DIR}/inception.crt"
CERT_KEY="${CERT_DIR}/inception.key"

mkdir -p "${CERT_DIR}"

if [ ! -f "${CERT_CRT}" ] || [ ! -f "${CERT_KEY}" ]; then
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "${CERT_KEY}" \
    -out "${CERT_CRT}" \
    -subj "/C=FR/L=Paris/O=42/OU=${LOGIN_NAME:-inception}/CN=${DOMAIN_NAME}"
fi

sed "s/__DOMAIN_NAME__/${DOMAIN_NAME}/g" \
  /etc/nginx/sites-available/inception-site.conf.template \
  > /etc/nginx/sites-available/inception-site.conf

ln -sf /etc/nginx/sites-available/inception-site.conf /etc/nginx/sites-enabled/inception-site.conf

exec "$@"
