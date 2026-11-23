# Changelog

Each entry lists breaking changes first. Railway notifies deployers when `main` changes.

## 2026-11-23: OpenUI efa45da (first release)

* OpenUI official image `ghcr.io/wandb/openui:sha-efa45da@sha256:d0a05926b4394b136cfb7cd3f908adb8db7a516286f1eba02cff2714904efdc7` (upstream commit `efa45da`, 2026-06-30; upstream has no release tags).
* Caddy 2.11.9 login proxy (`OPENUI_USERNAME` / generated `OPENUI_PASSWORD`) with an open `/healthz`.
* Data (SQLite database, session key) on a volume at `/data`.
* First-visit model `gpt-4o-mini` instead of the retired `gpt-3.5-turbo`; OpenUI listens on loopback only; W&B service off unless `WANDB_API_KEY` is set.
* LiteLLM proxy started only for providers that need it, watched by the start script.
