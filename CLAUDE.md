# CLAUDE.md — brickfinder

Project memory for Claude Code. Records non-obvious conventions, tooling, and
workflow decisions for this repo. Keep entries one paragraph each.

## Project

App that lets users photograph a pile of Lego bricks (official or third-party
compatible), recognizes the parts, finds buildable sets/MOCs from Rebrickable,
and links out to the original instructions. Chinese-first UI with English
fallback. No accounts; data lives on-device with optional JSON export/import.

See `docs/superpowers/specs/2026-06-21-lego-photo-build-finder-design.md` for
the full design, and `docs/superpowers/plans/` for milestone-scoped
implementation plans (currently only M1 is detailed).

## Repository layout

- `backend/` — FastAPI service (Python 3.12, async only)
- `app/` — Flutter cross-platform client (created in M2)
- `docs/superpowers/specs/` — design docs, one file per feature, dated
- `docs/superpowers/plans/` — implementation plans, one per milestone
- `deploy/` — server bootstrap docs and prod `.env` template
- `.github/workflows/` — CI + image build + deploy workflows

## Development workflow

Code is written locally. Nothing builds or releases from a developer's machine
— builds happen on GitHub Actions, releases happen on the remote server. The
loop is: write code → push branch / open PR → CI runs lint+tests → merge to
`main` → image is built and pushed to GHCR → deploy workflow SSHes to the
server and rolls the container.

### Backend local dev

```bash
cd backend
python -m venv .venv && . .venv/bin/activate
pip install -e ".[dev]"
docker compose -f docker-compose.dev.yml up -d   # Postgres + Redis only
export DATABASE_URL=postgresql+asyncpg://brickfinder:brickfinder@localhost:5432/brickfinder
export REDIS_URL=redis://localhost:6379/0
alembic upgrade head
uvicorn brickfinder.main:app --reload
```

We do NOT run the backend in Docker locally. The dev compose file only brings
up the dependencies. Run uvicorn natively for fast reload.

### Tests

- `pytest tests/unit` — fast, no Docker dependency, must pass on every commit
- `pytest tests/integration` — uses testcontainers (real Postgres + Redis);
  runnable locally and exercised by the nightly `backend-integration.yml`
  workflow; not run on every PR because Docker-in-Docker is slow and flaky
  on GitHub-hosted runners
- `ruff check .` — lint
- `mypy src` — type check (strict mode)
- External services (Brickognize, Rebrickable, DeepSeek) are NEVER hit in CI
  or unit tests; mock with `respx`. A nightly smoke job may exercise real
  upstreams once API keys are in repo secrets

## Release (CI/CD)

Three GitHub Actions workflows, one responsibility each:

1. `backend-ci.yml` — runs on every PR and push that touches `backend/`.
   Lints, type-checks, runs unit tests with coverage. Blocks merge on failure.
2. `backend-image.yml` — runs on push to `main` or a `v*` tag touching
   `backend/`. Builds the Docker image and pushes to both GHCR and Alibaba
   Cloud ACR (for fast pulls from mainland China) with tags `latest`,
   `sha-<short>`, and the git tag name. Uses `GITHUB_TOKEN` for GHCR and
   `ALIYUN_REGISTRY_USERNAME`/`ALIYUN_REGISTRY_PASSWORD` secrets for ACR.
3. `backend-deploy.yml` — triggers after `backend-image` succeeds, on a `v*`
   tag push, or via manual dispatch. SSHes into the deploy server, rewrites
   `IMAGE_TAG` in `/opt/brickfinder/.env`, runs `docker compose pull && up -d`,
   then health-checks `/health` with 60 retries × 5s. Fails the workflow (and
   surfaces container logs) if health doesn't come back.

`workflow_dispatch` is enabled on the image and deploy workflows so we can
rebuild or redeploy a specific tag without pushing new code. Pushing a tag
`v0.x.x` automatically builds and deploys that tag; `main` branch pushes still
deploy `latest`.

## Deployment topology

Single Linux server runs `docker-compose.prod.yml` (backend + Postgres +
Redis). The compose file and the `.env` (with secrets + image tag) live in
`/opt/brickfinder/` on the server. Bootstrap is one-time and manual; see
`deploy/server-bootstrap.md`. The deploy workflow only rewrites `IMAGE_TAG`,
pulls, and restarts — it never edits compose files or recreates volumes.

Image registry: images are pushed to both GitHub Container Registry (GHCR,
global fallback) and Alibaba Cloud Container Registry (ACR, primary for
deploy). The server pulls from ACR for fast downloads in mainland China.
ACR credentials (`ALIYUN_REGISTRY_USERNAME`/`ALIYUN_REGISTRY_PASSWORD`) are
stored as GitHub repo secrets and used by the image workflow for push; the
server does `docker login` once during bootstrap.

Reverse proxy / TLS is out of scope for M1 and not configured by these
workflows. Point Caddy/Nginx at `localhost:8000` if you need HTTPS.

## Required GitHub repo secrets

- `DEPLOY_HOST` — server hostname or IP (current: `121.37.166.59`)
- `DEPLOY_USER` — `root` on the current Huawei Cloud server (use a dedicated
  `deploy` user for production if possible)
- `DEPLOY_SSH_KEY` — private SSH key whose public half is in
  `~root/.ssh/authorized_keys` on the server
- `DEPLOY_PORT` — `22`
- `ALIYUN_REGISTRY_USERNAME` — Alibaba Cloud ACR username (for CI push)
- `ALIYUN_REGISTRY_PASSWORD` — Alibaba Cloud ACR password (for CI push)

The server also needs a one-time `docker login registry.cn-hangzhou.aliyuncs.com`
to pull private images from ACR.

## Coding conventions

- **Python**: 3.12+, FastAPI 0.110+, Pydantic v2 only (no v1 shims). All HTTP
  I/O async via `httpx.AsyncClient`. No `requests`. No sync DB drivers.
- **Errors**: every API failure normalizes to one of five codes —
  `INVALID_INPUT` / `UPSTREAM_TIMEOUT` / `UPSTREAM_ERROR` / `RATE_LIMITED` /
  `INTERNAL`. The client never sees upstream status codes or error bodies.
- **No user images on disk**: `UploadFile` stays in memory; the handle is
  closed before the response is sent. Don't log image bytes.
- **File size**: prefer focused files. If a module grows past ~300 lines,
  it's probably doing too much.
- **TDD**: write the failing test first, then the minimum code to pass.
  Commit at green. The M1 plan models the cadence.

## Decisions worth remembering

- **Recognition**: Brickognize API as primary; LLM/vision-model fallback was
  rejected because it can't count or distinguish 2x3 vs 2x4 reliably. Manual
  correction UI in the Flutter app is the required safety net, not optional.
- **Build matching**: Rebrickable's `parts/lists/build/` endpoint, strict
  mode by default, with a "≤5 missing kinds" toggle. User-configurable
  threshold in settings (range 1–10, default 5).
- **Instructions**: M1–MVP deep-links to the original instruction page on
  Rebrickable/LEGO.com. We do NOT embed PDFs or generate text-only steps
  from scratch — copyright risk for the first, LLM hallucination risk for
  the second.
- **Translations**: DeepSeek as primary LLM. Translation is on-demand
  (when a build detail page opens), per-field, cached permanently in Redis
  keyed by sha256 of the source text. English users skip translation.
- **No accounts**: backup is a JSON file the user exports/imports manually.
  The backend does not store raw user images or account profiles. It does
  store rate-limit counters keyed by client identifier (`X-Client-Id` header
  or client IP) and request logs, and it caches derived recognition results
  (aggregated part lists) in Redis keyed by the uploaded image's SHA-256.
- **Deploy timeout**: ACR pulls from mainland China are fast (~30s), so the
  SSH deploy step uses a 5-minute timeout and 60 × 5s health retries.
- **Tag releases**: Pushing a `v*` tag triggers both image build and deploy.
  Main-branch pushes still deploy `latest`.
- **Naive UTC datetimes**: SQLAlchemy `DateTime` columns use `timezone=False`
  and the code stores naive UTC datetimes. This avoids asyncpg errors on
  Postgres while keeping SQLite unit tests simple.
- **Integration test layout**: `tests/integration/conftest.py` lives inside
  `tests/integration/` so that `pytest tests/unit` never requires Docker.
- **Coverage target**: unit tests must cover at least 80% of
  `src/brickfinder/`; current baseline is ~93%.

## When in doubt

- Spec contradiction → check the design doc; if it's silent, ask the user
- Tooling question → check this file first, then `backend/README.md`
- Plan question → look in `docs/superpowers/plans/` for the current milestone
