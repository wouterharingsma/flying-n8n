FROM n8nio/n8n:latest

USER root

# --- Keep your old env defaults ---
ENV N8N_CUSTOM_EXTENSIONS=/home/node/.n8n/customnodes
ENV N8N_COMMUNITY_PACKAGES_ENABLED=true
ENV N8N_COMMUNITY_PACKAGES_REGISTRY=https://registry.npmjs.org
# keeping your legacy spelling to be 1:1 with old behavior
ENV N8N_BINARY_DATA_STORAGE_PATH=/home/node/.n8n/binairydata
ENV DB_SQLITE_VACUUM_ON_STARTUP=true
ENV TINI_SUBREAPER=true

# --- Install OS deps (works whether base uses apt or apk) ---
RUN set -eux; \
  if command -v apt-get >/dev/null 2>&1; then \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates \
      sqlite3 \
      python3 python3-pip python3-venv python3-dev \
      build-essential \
      gosu \
    ; \
    rm -rf /var/lib/apt/lists/*; \
  elif command -v apk >/dev/null 2>&1; then \
    apk add --no-cache \
      ca-certificates \
      sqlite \
      python3 py3-pip python3-dev \
      build-base \
      su-exec \
    ; \
  else \
    echo "ERROR: No supported package manager (apt-get/apk) found in base image."; \
    exit 1; \
  fi

# --- Create necessary directories + permissions (old behavior) ---
RUN mkdir -p \
      /home/node/.n8n/customnodes \
      /home/node/.n8n/binairydata \
      /home/node/.n8n/database \
      /home/node/python \
 && chown -R node:node /home/node/.n8n /home/node/python \
 && chmod -R 755 /home/node/.n8n

# --- Keep your legacy /root/.n8n link behavior ---
RUN rm -rf /root/.n8n && ln -s /home/node/.n8n /root/.n8n

# --- (Optional) replicate your build-time sqlite file creation (compat) ---
RUN sqlite3 /home/node/.n8n/database/yourdb.db \
      'CREATE TABLE IF NOT EXISTS customers (id INTEGER PRIMARY KEY, name TEXT);' \
 && chown node:node /home/node/.n8n/database /home/node/.n8n/database/yourdb.db \
 && chmod 0666 /home/node/.n8n/database/yourdb.db

# --- Python venv like before ---
RUN python3 -m venv /home/node/python/venv
ENV PATH="/home/node/python/venv/bin:$PATH"

# Requirements workflow (expects requirements.txt in build context)
COPY requirements.txt /home/node/python/requirements.txt
RUN chown -R node:node /home/node/python \
 && chmod -R 755 /home/node/python \
 && . /home/node/python/venv/bin/activate \
 && pip3 install --no-cache-dir -r /home/node/python/requirements.txt \
 && pip3 install --no-cache-dir fastapi uvicorn requests

# --- jsonwebtoken like before (use global to avoid cwd surprises) ---
RUN npm install -g jsonwebtoken

# --- Task runner config like before ---
ENV N8N_RUNNERS_MODE=internal_launcher \
    N8N_RUNNERS_LAUNCHER_PATH=/usr/local/bin/task-runner-launcher
COPY n8n-task-runners.json /etc/n8n-task-runners.json

# --- Your entrypoint ---
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 5678 8000
ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]