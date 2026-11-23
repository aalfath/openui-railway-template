# OpenUI for Railway: the official OpenUI image (W&B) with a small Caddy front
# that adds a login (HTTP basic auth) and an open /healthz for Railway.
# Upstream publishes no release tags, only per-commit images: this pins the image
# built from wandb/openui commit efa45da (2026-06-30, the newest backend/frontend code).
# Bump both pins together with a CHANGELOG.md entry; a merge to main notifies deployers.
FROM caddy:2.11.9-alpine@sha256:003a97808e781aa9f7e75cc2f43d34d461099031faf5e20faefb9f61126836f0 AS caddy

FROM ghcr.io/wandb/openui:sha-efa45da@sha256:d0a05926b4394b136cfb7cd3f908adb8db7a516286f1eba02cff2714904efdc7

COPY --from=caddy /usr/bin/caddy /usr/local/bin/caddy
COPY Caddyfile /etc/openui-railway/Caddyfile
COPY start.sh /usr/local/bin/openui-railway-start
RUN chmod 0755 /usr/local/bin/openui-railway-start \
 # The web UI's first-visit model is gpt-3.5-turbo, which OpenAI has retired: start on gpt-4o-mini.
 && grep -l '"model","gpt-3.5-turbo"' /app/openui/dist/assets/index-*.js > /tmp/bundle \
 && sed -i 's/"model","gpt-3.5-turbo"/"model","gpt-4o-mini"/' $(cat /tmp/bundle) \
 && grep -q '"model","gpt-4o-mini"' $(cat /tmp/bundle) && rm /tmp/bundle \
 # Keep the OpenUI server on loopback: only the login proxy is reachable, even on the private network.
 && sed -i 's/host="0.0.0.0" if is_running_in_docker() else "127.0.0.1"/host="127.0.0.1"/' /app/openui/__main__.py \
 && [ "$(grep -c 'host="127.0.0.1",' /app/openui/__main__.py)" = 2 ] \
 # Bake the tokenizer OpenUI uses to count tokens, so a cold start needs no download.
 && mkdir -p /opt/tiktoken \
 && TIKTOKEN_CACHE_DIR=/opt/tiktoken /app/.venv/bin/python -c "import tiktoken; tiktoken.get_encoding('cl100k_base')"

# OpenUI keeps its SQLite database and session key in $HOME/.openui: mount a volume at /data.
ENV HOME=/data \
    TIKTOKEN_CACHE_DIR=/opt/tiktoken \
    OPENUI_ENVIRONMENT=local \
    LITELLM_LOG=ERROR \
    PYTHONUNBUFFERED=1 \
    PORT=8080

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/openui-railway-start"]
