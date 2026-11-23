[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/openui?utm_medium=integration&utm_source=button&utm_campaign=openui)

# Deploy and Host OpenUI on Railway

OpenUI is an open-source tool from Weights & Biases that turns a plain-language description of a user interface into a live, rendered page. You describe a component or screen, OpenUI asks an LLM to write it in HTML with Tailwind CSS, shows it instantly, and lets you refine it by chat or convert it to React, Svelte or Web Components.

## About Hosting OpenUI

This template runs OpenUI's official image (built from upstream commit `efa45da`, pinned by digest) as one Railway service with a 1 GB volume at `/data` for its SQLite database and session key. A small Caddy proxy in front of it adds a login, because every request spends your LLM key: sign in with the user `openui` and the generated `OPENUI_PASSWORD` from the service's Variables tab. The only prompt is your OpenAI API key. After deploy, open the public URL, sign in, describe a UI and press Enter. The service fits in Railway's 0.5 GB plan (about 200 MB in use; about 410 MB when the LiteLLM proxy is on for Anthropic, Gemini or other providers).

## Common Use Cases

* Sketch a landing page, form or dashboard in words and get working HTML/Tailwind in seconds
* Iterate on a UI by chat or by annotating parts of the preview, then export it as React, Svelte or Web Components
* Give a design or product team a private, password-protected UI generator that uses your own OpenAI (or Groq, Anthropic, Gemini) account

## Dependencies for OpenUI Hosting

* An OpenAI API key (from https://platform.openai.com/api-keys), or another supported provider's key
* A Railway volume for OpenUI's SQLite database (included in the template)

### Deployment Dependencies

* OpenUI source and docs: https://github.com/wandb/openui
* Official image: https://github.com/wandb/openui/pkgs/container/openui
* Template repository (Dockerfile, start script, changelog): https://github.com/aalfath/openui-railway-template

### Implementation Details

The service you get:

* **OpenUI** (built from `aalfath/openui-railway-template`): the OpenUI web app and its LLM API on loopback, behind Caddy on `PORT` 8080. `/healthz` is the open health check; everything else asks for the login. The volume at `/data` keeps the database and session key, so logins and usage survive redeploys.

Variables:

* `OPENAI_API_KEY` (required): your OpenAI key. OpenUI offers `gpt-4o-mini` (default), `gpt-4o` and `gpt-4-turbo`.
* `OPENUI_PASSWORD`: generated on deploy; your login password. `OPENUI_USERNAME` defaults to `openui`.
* `OPENAI_BASE_URL`: OpenAI's API by default; point it at an OpenAI-compatible gateway that serves `gpt-*` model names if you use one.

Other providers (optional, add on the service's Variables tab and redeploy): `GROQ_API_KEY`; `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `COHERE_API_KEY` or `MISTRAL_API_KEY`; or `OPENAI_COMPATIBLE_ENDPOINT` plus `OPENAI_COMPATIBLE_API_KEY` for any OpenAI-compatible server (Ollama, vLLM, LM Studio, OpenRouter). The last group starts a LiteLLM proxy inside the service. Pick the model in OpenUI's settings. Ollama itself is not included: Railway has no GPUs, and a useful local model needs several GB of RAM.

Notes: generated pages preview in an iframe served from `wandb.github.io`, as upstream does for any hosted copy. Sharing links needs S3 settings (`AWS_ENDPOINT_URL_S3`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `BUCKET_NAME`) and is off by default. Weave tracing turns on if you add `WANDB_API_KEY`.

Updates: when this template's repository moves to a newer OpenUI build, Railway shows an update notice on your project; `CHANGELOG.md` in the repository lists each change, breaking ones first.

## Why Deploy OpenUI on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying OpenUI on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->

## Repository layout

* `Dockerfile`: pins the official OpenUI image (`ghcr.io/wandb/openui:sha-efa45da@sha256:d0a05926…`) and Caddy 2.11.9; sets the first-visit model to `gpt-4o-mini`, keeps OpenUI on loopback and bakes the tokenizer.
* `Caddyfile`: login (HTTP basic auth), open `/healthz`, and open placeholder images under `/openui/` for the preview iframe.
* `start.sh`: refuses to start without a 12+ character `OPENUI_PASSWORD`, starts OpenUI, Caddy and (only when needed) LiteLLM, and exits non-zero if any of them stops, so Railway restarts the service.
* `CHANGELOG.md`: one entry per version, breaking changes first.

OpenUI publishes no release tags, only per-commit images. This template pins the image of the newest backend/frontend commit and moves forward when upstream does.
