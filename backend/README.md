# brickfinder backend

FastAPI service that fronts Brickognize / Rebrickable / DeepSeek for the brickfinder app.

## Endpoints (M1)

- `GET /health` → `{"status": "ok"}`
- `POST /v1/recognize` (multipart, field `image`) → `RecognizeResponse`

## Local development

We run the backend natively for fast reload; Postgres + Redis live in Docker.

```bash
python -m venv .venv && . .venv/bin/activate
pip install -e ".[dev]"

# Start dependencies in Docker (Postgres + Redis only).
docker compose -f docker-compose.dev.yml up -d

# Apply DB schema.
export DATABASE_URL=postgresql+asyncpg://brickfinder:brickfinder@localhost:5432/brickfinder
export REDIS_URL=redis://localhost:6379/0
alembic upgrade head

# Run the server with hot reload.
uvicorn brickfinder.main:app --reload
```

## Tests

```bash
pytest tests/unit               # fast, no Docker needed
pytest tests/integration        # requires Docker (testcontainers)
ruff check .
mypy src
```

## Build & deploy story

Code lives on GitHub. Images are built by GitHub Actions and pushed to GHCR.
The remote server pulls the image and restarts via the `backend-deploy` workflow.
Developers never deploy from their local machine.

- `.github/workflows/backend-ci.yml` — lint + unit tests on every PR
- `.github/workflows/backend-image.yml` — build & push image on merge to `main` or `v*` tag
- `.github/workflows/backend-deploy.yml` — SSH to server, pull, restart, smoke-test
- `deploy/server-bootstrap.md` — one-time server setup

## Environment variables

See `.env.example`. Required at runtime: `DATABASE_URL`, `REDIS_URL`.

## Regenerating the color table

`src/brickfinder/colors/colors.json` ships a small seed. To pull the full Rebrickable list:

```bash
REBRICKABLE_API_KEY=xxxx python scripts/build_color_table.py
```

Commit the updated JSON.
