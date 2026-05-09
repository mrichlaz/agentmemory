# agentmemory-stack

Dockerized `agentmemory` setup prepared for self-hosting.

## What this includes

- Host-accessible REST API on `3111`
- Host-accessible viewer on `3113`
- Local embedding provider
- LLM-backed auto-compression enabled
- Graph extraction and consolidation enabled
- Docker build patch for OpenAI-compatible proxy deployments

## Why the Docker image is patched

Upstream `agentmemory` currently assumes the built-in OpenRouter endpoint in a few places. This stack patches the cloned source during Docker build so it can work with an OpenAI-compatible proxy/base URL.

The patch does three things:

- allows `OPENAI_API_KEY` to satisfy OpenRouter-style provider auth
- allows custom `OPENROUTER_BASE_URL`
- forces `stream: false` for compression requests so nonstandard SSE proxy responses do not break JSON parsing

## Files

- `Dockerfile` — builds and patches upstream `agentmemory`
- `docker-compose.yml` — runtime wiring and host port publishing
- `.env.example` — example environment values

## Setup

1. Copy the example env file:

```bash
cp .env.example .env
```

2. Edit `.env` with your real values.

3. Start the stack:

```bash
docker compose up --build -d
```

4. Check logs:

```bash
docker compose logs -f
```

## Endpoints

- API health:

```bash
curl -H 'Authorization: Bearer YOUR_SECRET' \
  http://localhost:3111/agentmemory/health
```

- Feature flags:

```bash
curl -H 'Authorization: Bearer YOUR_SECRET' \
  http://localhost:3111/agentmemory/config/flags
```

- Viewer:

```bash
http://localhost:3113/viewer
```

## Server deployment notes

- open TCP ports `3111` and `3113` on your server if accessed directly
- if using Nginx/Caddy, proxy those ports to the container host
- keep `.env` out of git
- rotate `AGENTMEMORY_SECRET` and API keys before production use

## Current known caveats

- search/delete semantics in upstream `agentmemory` may still need additional fixes unrelated to the compression fix
- search/delete semantics in upstream `agentmemory` may still need additional fixes unrelated to the compression fix

## Port mapping

This stack now binds directly on matching host/container ports:

- `3111:3111` for the REST API
- `3113:3113` for the viewer

The Docker build patches upstream bind addresses to `0.0.0.0` so no `socat` forwarding layer is needed.

## Update workflow

When you pull changes later, rebuild the image so the source patch is re-applied:

```bash
docker compose up --build -d
```
