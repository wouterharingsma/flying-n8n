#!/bin/bash
set -e

if [ -d /opt/custom-certificates ]; then
  echo "Trusting custom certificates from /opt/custom-certificates."
  export NODE_OPTIONS=--use-openssl-ca $NODE_OPTIONS
  export SSL_CERT_DIR=/opt/custom-certificates
  c_rehash /opt/custom-certificates
fi

# Fly volumes can mount as root-owned. This keeps behavior compatible either way.
if [ -d "/home/node/.n8n" ]; then
  chmod -R 755 /home/node/.n8n || true
fi

# Start n8n (same behavior as your old entrypoint)
if [ "$#" -gt 0 ]; then
  exec n8n "$@"
else
  exec n8n start
fi
