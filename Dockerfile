FROM n8nio/n8n:latest

USER root

ARG COREPACK_YES=1
ARG COREPACK_ENABLE_NETWORK=1

# Keep your old env defaults as-is (including your existing path spelling)
ENV N8N_CUSTOM_EXTENSIONS=/home/node/.n8n/customnodes
ENV N8N_COMMUNITY_PACKAGES_ENABLED=true
ENV N8N_COMMUNITY_PACKAGES_REGISTRY=https://registry.npmjs.org
ENV N8N_BINARY_DATA_STORAGE_PATH=/home/node/.n8n/binairydata
ENV DB_SQLITE_VACUUM_ON_STARTUP=true
ENV TINI_SUBREAPER=true

# Packages you previously installed (Alpine-based image)
RUN apk add --no-cache \
    su-exec \
    python3 py3-pip python3-dev \
    sqlite \
    ca-certificates

# Create necessary directories + permissions
RUN mkdir -p /home/node/.n8n/customnodes \
    /home/node/.n8n/binairydata \
    /home/node/.n8n/database \
    /home/node/python \
 && chown -R node:node /home/node/.n8n /home/node/python \
 && chmod -R 755 /home/node/.n8n

# Keep your legacy /root/.n8n link behavior
RUN rm -rf /root/.n8n && ln -s /home/node/.n8n /root/.n8n

# (Optional) replicate your build-time sqlite file creation (kept for compatibility)
# Note: runtime will typically use the Fly volume anyway.
RUN sqlite3 /home/node/.n8n/database/yourdb.db \
      'CREATE TABLE IF NOT EXISTS customers (id INTEGER PRIMARY KEY, name TEXT);' \
 && chown node:node /home/node/.n8n/database /home/node/.n8n/database/yourdb.db \
 && chmod 0666 /home/node/.n8n/database/yourdb.db

# Python venv like before
RUN python3 -m venv /home/node/python/venv
ENV PATH="/home/node/python/venv/bin:$PATH"

# Keep your existing requirements workflow (expects requirements.txt in build context)
COPY requirements.txt /home/node/python/requirements.txt
RUN chown -R node:node /home/node/python && chmod -R 755 /home/node/python \
 && . /home/node/python/venv/bin/activate \
 && pip3 install --no-cache-dir -r /home/node/python/requirements.txt \
 && pip3 install --no-cache-dir fastapi uvicorn requests

# Task runner config like before
RUN npm install jsonwebtoken
ENV N8N_RUNNERS_MODE=internal_launcher \
    N8N_RUNNERS_LAUNCHER_PATH=/usr/local/bin/task-runner-launcher
COPY n8n-task-runners.json /etc/n8n-task-runners.json

# Entry point (replaces your current docker-entrypoint.sh)
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 5678 8000
ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]