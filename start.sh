#!/bin/sh
# Start OpenUI (127.0.0.1:7878), Caddy ($PORT: login + /healthz) and, only when a
# provider needs it, a LiteLLM proxy (127.0.0.1:4000).
# Exits non-zero as soon as either process stops, so Railway restarts the service.
set -eu

export OPENUI_USERNAME="${OPENUI_USERNAME:-openui}"
if [ -z "${OPENUI_PASSWORD:-}" ] || [ "${#OPENUI_PASSWORD}" -lt 12 ]; then
	echo "openui-railway: OPENUI_PASSWORD must be set (12+ characters). Refusing to start an open server that spends your API key." >&2
	exit 1
fi
if [ -z "${OPENAI_API_KEY:-}" ] && [ -z "${GROQ_API_KEY:-}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ] \
	&& [ -z "${GEMINI_API_KEY:-}" ] && [ -z "${OPENAI_COMPATIBLE_ENDPOINT:-}" ]; then
	echo "openui-railway: warning: no LLM key set (OPENAI_API_KEY or another provider), so no models will be listed." >&2
fi

mkdir -p "$HOME/.openui" /tmp/caddy

# Importing OpenUI starts a W&B "wandb-service" helper (about 80 MB) even without a
# W&B key. Keep it off unless the deployer opts into Weave tracing with WANDB_API_KEY.
if [ -z "${WANDB_API_KEY:-}" ]; then
	export WANDB_MODE="${WANDB_MODE:-disabled}"
fi

# OpenUI talks to OpenAI (gpt-* models) and Groq directly. For Anthropic, Gemini,
# Cohere, Mistral or any OpenAI-compatible endpoint it needs a LiteLLM proxy. Upstream's
# --litellm flag starts one with its output piped and never read (it stalls once the
# pipe fills), so start it here instead: loopback only, a fresh random key per boot,
# logs to Railway, and watched like the other two processes.
use_litellm=0
for v in ANTHROPIC_API_KEY GEMINI_API_KEY COHERE_API_KEY MISTRAL_API_KEY OPENAI_COMPATIBLE_ENDPOINT; do
	eval "val=\${$v:-}"
	[ -n "$val" ] && use_litellm=1
done
LITELLM_MASTER_KEY="sk-$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')"
export LITELLM_MASTER_KEY LITELLM_API_KEY="$LITELLM_MASTER_KEY" LITELLM_BASE_URL="http://127.0.0.1:4000"

OPENUI_PASSWORD_HASH=$(caddy hash-password --algorithm bcrypt --bcrypt-cost 10 --plaintext "$OPENUI_PASSWORD")
proxy_port="${PORT:-8080}"
cd /app

llm=""
if [ "$use_litellm" = 1 ]; then
	cfg=$(env -u OPENUI_PASSWORD python -c 'from openui.litellm import generate_config; print(generate_config())' 2>/dev/null | tail -n 1)
	env -u OPENUI_PASSWORD litellm --config "$cfg" --host 127.0.0.1 --port 4000 --num_workers 1 &
	llm=$!
fi

env -u OPENUI_PASSWORD PORT=7878 python -m openui &
app=$!
env -u OPENUI_PASSWORD -u OPENAI_API_KEY -u LITELLM_MASTER_KEY -u LITELLM_API_KEY OPENUI_PASSWORD_HASH="$OPENUI_PASSWORD_HASH" PORT="$proxy_port" \
	XDG_CONFIG_HOME=/tmp/caddy XDG_DATA_HOME=/tmp/caddy GOMEMLIMIT="${GOMEMLIMIT:-48MiB}" \
	caddy run --adapter caddyfile --config /etc/openui-railway/Caddyfile &
proxy=$!
unset OPENUI_PASSWORD_HASH

stopping=0
term() {
	stopping=1
	kill -TERM "$app" "$proxy" $llm 2>/dev/null || true
}
trap term TERM INT

echo "openui-railway: OpenUI starting (LiteLLM proxy: $([ -n "$llm" ] && echo on || echo off); data in $HOME/.openui; login user $OPENUI_USERNAME)"
alive() {
	kill -0 "$app" 2>/dev/null && kill -0 "$proxy" 2>/dev/null || return 1
	[ -z "$llm" ] || kill -0 "$llm" 2>/dev/null
}
while alive; do
	sleep 2 &
	wait $! || true
done

kill -TERM "$app" "$proxy" $llm 2>/dev/null || true
[ -z "$llm" ] || wait "$llm" 2>/dev/null || true
wait "$app" 2>/dev/null || true
wait "$proxy" 2>/dev/null || true
if [ "$stopping" = 1 ]; then
	exit 0
fi
echo "openui-railway: a process stopped unexpectedly; exiting 1 so Railway restarts the service" >&2
exit 1
