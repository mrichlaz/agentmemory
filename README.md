# agentmemory-stack

Upstream-native `agentmemory` stack for self-hosting.

## What this includes

- REST API on `3111`
- stream service on `3112`
- viewer/admin panel on `3113`
- persistent `/data` volume
- pinned upstream `iii` engine runtime
- no source patching during build

## Why this shape

Old stack cloned upstream source during Docker build and rewrote files with exact-string patches. Upstream updates changed those files, patches drifted, and behavior broke silently.

This stack now follows upstream runtime pattern instead:

- run pinned `iiidev/iii` image
- mount repo-owned `iii-config.docker.yaml`
- keep config in `.env`
- update by bumping version pin, not rebuilding patched source

## Files

- `docker-compose.yml` — upstream-style runtime wiring
- `iii-config.docker.yaml` — engine config mounted into container
- `.env.example` — example environment values

## Setup

1. Copy example env file:

```bash
cp .env.example .env
```

2. Edit `.env` with real values.

3. Start stack:

```bash
docker compose up -d
```

4. Check logs:

```bash
docker compose logs --no-color --tail=200
```

## Endpoints

### Health

```bash
curl -H 'Authorization: Bearer YOUR_SECRET' \
  http://localhost:3111/agentmemory/health
```

### Feature flags

```bash
curl -H 'Authorization: Bearer YOUR_SECRET' \
  http://localhost:3111/agentmemory/config/flags
```

### Viewer / admin panel

Open:

```text
http://localhost:3113/viewer
```

## Version updates

Bump engine version in `.env`:

```env
AGENTMEMORY_III_VERSION=0.11.2
```

Then restart:

```bash
docker compose up -d
```

Smoke test after each update:

```bash
docker compose config
curl -H 'Authorization: Bearer YOUR_SECRET' http://localhost:3111/agentmemory/health
curl -H 'Authorization: Bearer YOUR_SECRET' http://localhost:3111/agentmemory/config/flags
```

Then open `http://localhost:3113/viewer` and confirm dashboard loads.

## Notes

- Stack now uses upstream-native provider behavior only.
- Old OpenAI-compatible proxy patch behavior was removed.
- `3111`, `3112`, `3113`, and `9464` are bound to `127.0.0.1` by default.
- Keep `.env` out of git.
- Rotate `AGENTMEMORY_SECRET` and provider keys before production use.
