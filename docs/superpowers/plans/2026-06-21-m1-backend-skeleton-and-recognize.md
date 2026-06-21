# M1 — 后端骨架 + 识别打通 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a FastAPI backend that accepts a photo upload, calls Brickognize, normalizes the result against the Rebrickable color table, caches in Redis, enforces per-client rate limits, trips a circuit breaker on upstream failures, and returns a unified-error-shape JSON payload that the Flutter app will consume in M2.

**Architecture:** Single FastAPI app, started via docker-compose alongside Postgres (quota + log) and Redis (cache). Three layers: routes → services → upstream-clients. The recognize route is the only user-facing surface for M1; `/health` and a one-shot offline color-table generator round out the milestone.

**Tech Stack:** Python 3.12, FastAPI, uvicorn, httpx (async), Pydantic v2, Redis (`redis-py` async), Postgres + SQLAlchemy 2.x async + Alembic, pytest + pytest-asyncio + respx + testcontainers, ruff + mypy, structlog, docker-compose.

## Global Constraints

- Python 3.12+; FastAPI 0.110+; Pydantic v2 only.
- All HTTP I/O is async (`httpx.AsyncClient`). No `requests`, no sync DB drivers.
- Never log or persist user-uploaded image bytes. `UploadFile` stays in memory; the file handle is closed before the response is sent.
- Never expose upstream HTTP codes or error bodies to the client. All errors are normalized into the 5-code schema (`INVALID_INPUT`, `UPSTREAM_TIMEOUT`, `UPSTREAM_ERROR`, `RATE_LIMITED`, `INTERNAL`).
- Image upload max size: **8 MB** (reject larger with `INVALID_INPUT`).
- Per-client daily quotas (M1 scope): `recognize=100`. Rolling 24-hour window.
- Upstream timeouts (M1 scope): Brickognize 30s, overall request 60s.
- Circuit breaker: 10 consecutive upstream failures → open for 30s.
- Redis key TTLs are exactly as specified: `recog:img:<sha256>` = 7 days.

## File Structure

```
backend/
├── pyproject.toml                  # uv / pip-tools deps, ruff/mypy config
├── docker-compose.yml              # postgres, redis, backend
├── Dockerfile                      # backend image
├── .env.example                    # all env vars with safe defaults
├── alembic.ini
├── alembic/
│   ├── env.py
│   └── versions/
├── src/
│   └── brickfinder/
│       ├── __init__.py
│       ├── main.py                 # FastAPI app factory, lifespan
│       ├── config.py               # Pydantic Settings
│       ├── logging.py              # structlog setup
│       ├── errors.py               # AppError + 5-code schema + handlers
│       ├── deps.py                 # FastAPI dependencies (db, redis, client_key)
│       ├── routes/
│       │   ├── __init__.py
│       │   ├── health.py           # GET /health
│       │   └── recognize.py        # POST /v1/recognize
│       ├── services/
│       │   ├── __init__.py
│       │   └── recognize.py        # RecognizeService
│       ├── upstream/
│       │   ├── __init__.py
│       │   ├── brickognize.py      # async client + circuit breaker
│       │   └── breaker.py          # CircuitBreaker primitive
│       ├── cache/
│       │   ├── __init__.py
│       │   └── redis_cache.py      # JSON-typed get/set with TTL
│       ├── quota/
│       │   ├── __init__.py
│       │   └── rate_limit.py       # rolling-window quota check + bump
│       ├── db/
│       │   ├── __init__.py
│       │   ├── engine.py           # async engine + session
│       │   └── models.py           # RateQuota, ApiCallLog
│       ├── colors/
│       │   ├── __init__.py
│       │   ├── table.py            # ColorTable (loaded from JSON at startup)
│       │   └── colors.json         # generated; checked in
│       └── schemas/
│           ├── __init__.py
│           ├── common.py           # ErrorResponse
│           └── recognize.py        # RecognizeResponse, PartItem
├── scripts/
│   └── build_color_table.py        # one-shot: Rebrickable colors → colors.json
└── tests/
    ├── conftest.py                 # fixtures: app, db, redis, respx mock
    ├── unit/
    │   ├── test_color_table.py
    │   ├── test_recognize_service.py
    │   ├── test_breaker.py
    │   ├── test_cache.py
    │   ├── test_rate_limit.py
    │   └── test_errors.py
    └── integration/
        ├── test_health.py
        └── test_recognize_route.py
```

Each file has one responsibility. Routes are thin (validation + service call). Services own the orchestration logic and are the unit-test target. Upstream clients own one third-party API each. Cache, quota, db, colors are independent primitives.

---

### Task 1: Project skeleton, dependencies, lint config

**Files:**
- Create: `backend/pyproject.toml`
- Create: `backend/.gitignore`
- Create: `backend/.env.example`
- Create: `backend/README.md`
- Create: `backend/src/brickfinder/__init__.py`

**Interfaces:**
- Consumes: nothing
- Produces: a runnable Python project where `pytest` exits 0 (no tests yet, but discovery works) and `ruff check .` / `mypy src` pass.

- [ ] **Step 1: Create pyproject.toml**

Create `backend/pyproject.toml`:

```toml
[project]
name = "brickfinder"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = [
  "fastapi>=0.110",
  "uvicorn[standard]>=0.27",
  "pydantic>=2.6",
  "pydantic-settings>=2.2",
  "httpx>=0.27",
  "redis>=5.0",
  "sqlalchemy[asyncio]>=2.0",
  "asyncpg>=0.29",
  "alembic>=1.13",
  "python-multipart>=0.0.9",
  "structlog>=24.1",
  "Pillow>=10.2",
]

[project.optional-dependencies]
dev = [
  "pytest>=8.0",
  "pytest-asyncio>=0.23",
  "pytest-cov>=4.1",
  "respx>=0.20",
  "testcontainers[postgres,redis]>=4.0",
  "ruff>=0.3",
  "mypy>=1.9",
  "types-redis",
]

[build-system]
requires = ["setuptools>=68"]
build-backend = "setuptools.build_meta"

[tool.setuptools.packages.find]
where = ["src"]

[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]
addopts = "-q --strict-markers"

[tool.ruff]
line-length = 100
target-version = "py312"

[tool.ruff.lint]
select = ["E", "F", "I", "B", "UP", "RUF"]
ignore = ["E501"]

[tool.mypy]
python_version = "3.12"
strict = true
packages = ["brickfinder"]
mypy_path = "src"
```

- [ ] **Step 2: Create .gitignore**

Create `backend/.gitignore`:

```
__pycache__/
*.py[cod]
.venv/
.env
.coverage
.pytest_cache/
.ruff_cache/
.mypy_cache/
dist/
*.egg-info/
```

- [ ] **Step 3: Create .env.example**

Create `backend/.env.example`:

```
APP_ENV=local
LOG_LEVEL=INFO

DATABASE_URL=postgresql+asyncpg://brickfinder:brickfinder@localhost:5432/brickfinder
REDIS_URL=redis://localhost:6379/0

BRICKOGNIZE_BASE_URL=https://api.brickognize.com
BRICKOGNIZE_TIMEOUT_SECONDS=30

RATE_LIMIT_RECOGNIZE_PER_DAY=100

CIRCUIT_BREAKER_THRESHOLD=10
CIRCUIT_BREAKER_COOLDOWN_SECONDS=30

UPLOAD_MAX_BYTES=8388608
```

- [ ] **Step 4: Create empty package marker and README stub**

Create `backend/src/brickfinder/__init__.py` (empty file).

Create `backend/README.md`:

```markdown
# brickfinder backend

FastAPI service that fronts Brickognize / Rebrickable / DeepSeek.

## Run locally

    docker-compose up -d postgres redis
    uv pip install -e ".[dev]"
    uvicorn brickfinder.main:app --reload

See `.env.example` for configuration.
```

- [ ] **Step 5: Install and verify**

Run from `backend/`:

```bash
python -m venv .venv && . .venv/bin/activate
pip install -e ".[dev]"
ruff check .
mypy src
pytest
```

Expected: `ruff` and `mypy` exit 0. `pytest` reports `no tests ran` (exit 5 is acceptable; treat as pass).

- [ ] **Step 6: Commit**

```bash
git add backend/
git commit -m "feat(backend): project skeleton with deps and lint config"
```

---

### Task 2: Pydantic Settings and config loading

**Files:**
- Create: `backend/src/brickfinder/config.py`
- Create: `backend/tests/unit/test_config.py`

**Interfaces:**
- Consumes: env vars from `.env.example`
- Produces:
  - `class Settings(BaseSettings)` with fields matching `.env.example` (snake_case names).
  - `get_settings() -> Settings` — cached accessor (LRU).
  - Field names other tasks rely on: `database_url: str`, `redis_url: str`, `brickognize_base_url: str`, `brickognize_timeout_seconds: float`, `rate_limit_recognize_per_day: int`, `circuit_breaker_threshold: int`, `circuit_breaker_cooldown_seconds: float`, `upload_max_bytes: int`, `log_level: str`, `app_env: str`.

- [ ] **Step 1: Write the failing test**

Create `backend/tests/unit/test_config.py`:

```python
from brickfinder.config import Settings


def test_settings_load_from_env(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "postgresql+asyncpg://u:p@h:5432/d")
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379/1")
    monkeypatch.setenv("BRICKOGNIZE_BASE_URL", "https://example.com")
    monkeypatch.setenv("BRICKOGNIZE_TIMEOUT_SECONDS", "12.5")
    monkeypatch.setenv("RATE_LIMIT_RECOGNIZE_PER_DAY", "7")
    monkeypatch.setenv("CIRCUIT_BREAKER_THRESHOLD", "3")
    monkeypatch.setenv("CIRCUIT_BREAKER_COOLDOWN_SECONDS", "11")
    monkeypatch.setenv("UPLOAD_MAX_BYTES", "1024")
    monkeypatch.setenv("LOG_LEVEL", "DEBUG")
    monkeypatch.setenv("APP_ENV", "test")

    s = Settings()

    assert s.database_url == "postgresql+asyncpg://u:p@h:5432/d"
    assert s.redis_url == "redis://localhost:6379/1"
    assert s.brickognize_base_url == "https://example.com"
    assert s.brickognize_timeout_seconds == 12.5
    assert s.rate_limit_recognize_per_day == 7
    assert s.circuit_breaker_threshold == 3
    assert s.circuit_breaker_cooldown_seconds == 11
    assert s.upload_max_bytes == 1024
    assert s.log_level == "DEBUG"
    assert s.app_env == "test"


def test_settings_defaults():
    # Required vars still have to be set; only optional ones default.
    import os
    os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://x")
    os.environ.setdefault("REDIS_URL", "redis://x")
    s = Settings()
    assert s.upload_max_bytes == 8 * 1024 * 1024
```

- [ ] **Step 2: Run the test, expect failure**

```bash
pytest tests/unit/test_config.py -v
```

Expected: ImportError — module `brickfinder.config` not found.

- [ ] **Step 3: Implement Settings**

Create `backend/src/brickfinder/config.py`:

```python
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "local"
    log_level: str = "INFO"

    database_url: str
    redis_url: str

    brickognize_base_url: str = "https://api.brickognize.com"
    brickognize_timeout_seconds: float = 30.0

    rate_limit_recognize_per_day: int = 100

    circuit_breaker_threshold: int = 10
    circuit_breaker_cooldown_seconds: float = 30.0

    upload_max_bytes: int = 8 * 1024 * 1024  # 8 MB


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()  # type: ignore[call-arg]
```

- [ ] **Step 4: Run the test, expect pass**

```bash
pytest tests/unit/test_config.py -v
```

Expected: 2 passed.

- [ ] **Step 5: Commit**

```bash
git add backend/src/brickfinder/config.py backend/tests/unit/test_config.py
git commit -m "feat(backend): Settings loaded from env vars"
```

---

### Task 3: Structured logging setup

**Files:**
- Create: `backend/src/brickfinder/logging.py`
- Create: `backend/tests/unit/test_logging.py`

**Interfaces:**
- Consumes: `Settings.log_level`
- Produces: `configure_logging(settings: Settings) -> None`; `get_logger(name: str) -> structlog.BoundLogger`.

- [ ] **Step 1: Write failing test**

Create `backend/tests/unit/test_logging.py`:

```python
import json
import logging

from brickfinder.config import Settings
from brickfinder.logging import configure_logging, get_logger


def test_logger_emits_json(capsys):
    settings = Settings(
        database_url="postgresql+asyncpg://x",
        redis_url="redis://x",
        log_level="INFO",
    )  # type: ignore[call-arg]
    configure_logging(settings)
    log = get_logger("test")
    log.info("hello", route="/v1/recognize", cache_hit=False)

    captured = capsys.readouterr()
    payload = json.loads(captured.out.strip().splitlines()[-1])
    assert payload["event"] == "hello"
    assert payload["route"] == "/v1/recognize"
    assert payload["cache_hit"] is False
    assert payload["level"] == "info"


def test_log_level_respected(capsys):
    settings = Settings(
        database_url="postgresql+asyncpg://x",
        redis_url="redis://x",
        log_level="WARNING",
    )  # type: ignore[call-arg]
    configure_logging(settings)
    log = get_logger("test")
    log.debug("hidden")
    log.warning("visible")
    captured = capsys.readouterr()
    lines = [l for l in captured.out.strip().splitlines() if l]
    assert any("visible" in l for l in lines)
    assert not any("hidden" in l for l in lines)
```

- [ ] **Step 2: Run, expect failure**

```bash
pytest tests/unit/test_logging.py -v
```

Expected: ImportError.

- [ ] **Step 3: Implement**

Create `backend/src/brickfinder/logging.py`:

```python
import logging
import sys

import structlog

from .config import Settings


def configure_logging(settings: Settings) -> None:
    level = getattr(logging, settings.log_level.upper(), logging.INFO)
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=level,
        force=True,
    )
    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.processors.add_log_level,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.JSONRenderer(),
        ],
        wrapper_class=structlog.make_filtering_bound_logger(level),
        logger_factory=structlog.PrintLoggerFactory(),
        cache_logger_on_first_use=True,
    )


def get_logger(name: str) -> structlog.stdlib.BoundLogger:
    return structlog.get_logger(name)  # type: ignore[return-value]
```

- [ ] **Step 4: Run, expect pass**

```bash
pytest tests/unit/test_logging.py -v
```

Expected: 2 passed.

- [ ] **Step 5: Commit**

```bash
git add backend/src/brickfinder/logging.py backend/tests/unit/test_logging.py
git commit -m "feat(backend): structured JSON logging"
```

---

### Task 4: Error schema and exception handlers

**Files:**
- Create: `backend/src/brickfinder/errors.py`
- Create: `backend/src/brickfinder/schemas/__init__.py`
- Create: `backend/src/brickfinder/schemas/common.py`
- Create: `backend/tests/unit/test_errors.py`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `class ErrorCode(StrEnum)` with members `INVALID_INPUT`, `UPSTREAM_TIMEOUT`, `UPSTREAM_ERROR`, `RATE_LIMITED`, `INTERNAL`.
  - `class AppError(Exception)` with `__init__(self, code: ErrorCode, message: str, *, http_status: int, retry_after_seconds: int | None = None)`.
  - `class ErrorResponse(BaseModel)` with fields `code: ErrorCode`, `message: str`, `retry_after_seconds: int | None`.
  - `register_exception_handlers(app: FastAPI) -> None` — installs handlers for `AppError`, `RequestValidationError`, generic `Exception`.

- [ ] **Step 1: Write failing test**

Create `backend/tests/unit/test_errors.py`:

```python
from fastapi import FastAPI
from fastapi.testclient import TestClient

from brickfinder.errors import AppError, ErrorCode, register_exception_handlers
from brickfinder.schemas.common import ErrorResponse


def _build_app() -> FastAPI:
    app = FastAPI()

    @app.get("/boom")
    def boom() -> None:
        raise AppError(
            code=ErrorCode.UPSTREAM_TIMEOUT,
            message="Brickognize timed out",
            http_status=504,
            retry_after_seconds=5,
        )

    @app.get("/oops")
    def oops() -> None:
        raise RuntimeError("internal failure")

    register_exception_handlers(app)
    return app


def test_app_error_serialized():
    client = TestClient(_build_app())
    r = client.get("/boom")
    assert r.status_code == 504
    body = r.json()
    parsed = ErrorResponse.model_validate(body)
    assert parsed.code == ErrorCode.UPSTREAM_TIMEOUT
    assert parsed.message == "Brickognize timed out"
    assert parsed.retry_after_seconds == 5


def test_unhandled_exception_becomes_internal():
    client = TestClient(_build_app())
    r = client.get("/oops")
    assert r.status_code == 500
    body = r.json()
    parsed = ErrorResponse.model_validate(body)
    assert parsed.code == ErrorCode.INTERNAL
    # Must NOT leak the original message
    assert "internal failure" not in parsed.message
```

- [ ] **Step 2: Run, expect failure**

```bash
pytest tests/unit/test_errors.py -v
```

Expected: ImportError.

- [ ] **Step 3: Implement schemas/common.py**

Create `backend/src/brickfinder/schemas/__init__.py` (empty).

Create `backend/src/brickfinder/schemas/common.py`:

```python
from enum import StrEnum

from pydantic import BaseModel


class ErrorCode(StrEnum):
    INVALID_INPUT = "INVALID_INPUT"
    UPSTREAM_TIMEOUT = "UPSTREAM_TIMEOUT"
    UPSTREAM_ERROR = "UPSTREAM_ERROR"
    RATE_LIMITED = "RATE_LIMITED"
    INTERNAL = "INTERNAL"


class ErrorResponse(BaseModel):
    code: ErrorCode
    message: str
    retry_after_seconds: int | None = None
```

- [ ] **Step 4: Implement errors.py**

Create `backend/src/brickfinder/errors.py`:

```python
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from .logging import get_logger
from .schemas.common import ErrorCode, ErrorResponse

log = get_logger(__name__)


class AppError(Exception):
    def __init__(
        self,
        code: ErrorCode,
        message: str,
        *,
        http_status: int,
        retry_after_seconds: int | None = None,
    ) -> None:
        self.code = code
        self.message = message
        self.http_status = http_status
        self.retry_after_seconds = retry_after_seconds
        super().__init__(message)


def _json(body: ErrorResponse, status: int) -> JSONResponse:
    return JSONResponse(status_code=status, content=body.model_dump(mode="json"))


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def _handle_app_error(_: Request, exc: AppError) -> JSONResponse:
        return _json(
            ErrorResponse(
                code=exc.code,
                message=exc.message,
                retry_after_seconds=exc.retry_after_seconds,
            ),
            exc.http_status,
        )

    @app.exception_handler(RequestValidationError)
    async def _handle_validation(_: Request, exc: RequestValidationError) -> JSONResponse:
        return _json(
            ErrorResponse(code=ErrorCode.INVALID_INPUT, message="Invalid request"),
            400,
        )

    @app.exception_handler(Exception)
    async def _handle_unexpected(_: Request, exc: Exception) -> JSONResponse:
        log.exception("unhandled_exception", error=repr(exc))
        return _json(
            ErrorResponse(code=ErrorCode.INTERNAL, message="Internal error"),
            500,
        )
```

- [ ] **Step 5: Run, expect pass**

```bash
pytest tests/unit/test_errors.py -v
```

Expected: 2 passed.

- [ ] **Step 6: Commit**

```bash
git add backend/src/brickfinder/errors.py backend/src/brickfinder/schemas/
git add backend/tests/unit/test_errors.py
git commit -m "feat(backend): unified error schema and handlers"
```

---

### Task 5: Color table generator script + ColorTable

**Files:**
- Create: `backend/scripts/build_color_table.py`
- Create: `backend/src/brickfinder/colors/__init__.py`
- Create: `backend/src/brickfinder/colors/table.py`
- Create: `backend/src/brickfinder/colors/colors.json`
- Create: `backend/tests/unit/test_color_table.py`

**Interfaces:**
- Consumes: a pre-generated `colors.json` (committed to the repo). The generator is run by humans, not at runtime.
- Produces:
  - `class ColorTable` with method `lookup(name: str) -> int` — returns Rebrickable color_id, or `-1` for unknown.
  - `load_default() -> ColorTable` — reads `colors.json` from the package directory.
  - The JSON file format: `{"colors": [{"id": 0, "name": "Black", "aliases": ["black"]}, ...]}` — names and aliases are case-insensitive on lookup.

- [ ] **Step 1: Write the generator script**

Create `backend/scripts/build_color_table.py`:

```python
"""
One-shot: pull Rebrickable colors and emit colors.json with normalized aliases.

Usage:
    REBRICKABLE_API_KEY=xxx python scripts/build_color_table.py

Writes to src/brickfinder/colors/colors.json. Run only when the upstream
color list changes (rarely).
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

import httpx

OUT = Path(__file__).resolve().parents[1] / "src" / "brickfinder" / "colors" / "colors.json"


def _alias(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", name.lower()).strip()


def main() -> int:
    key = os.environ.get("REBRICKABLE_API_KEY")
    if not key:
        print("REBRICKABLE_API_KEY required", file=sys.stderr)
        return 2

    headers = {"Authorization": f"key {key}"}
    colors: list[dict[str, object]] = []
    url = "https://rebrickable.com/api/v3/lego/colors/?page_size=1000"
    with httpx.Client(timeout=30) as client:
        while url:
            r = client.get(url, headers=headers)
            r.raise_for_status()
            data = r.json()
            for c in data["results"]:
                aliases = {_alias(c["name"])}
                # Brickognize tends to return space-stripped lowercase
                aliases.add(c["name"].lower().replace(" ", ""))
                colors.append({"id": c["id"], "name": c["name"], "aliases": sorted(aliases)})
            url = data.get("next")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"colors": colors}, indent=2, sort_keys=True))
    print(f"wrote {len(colors)} colors to {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 2: Seed a minimal colors.json**

Create `backend/src/brickfinder/colors/__init__.py` (empty).

Create `backend/src/brickfinder/colors/colors.json`:

```json
{
  "colors": [
    {"id": 0,  "name": "Black",         "aliases": ["black"]},
    {"id": 1,  "name": "Blue",          "aliases": ["blue"]},
    {"id": 2,  "name": "Green",         "aliases": ["green"]},
    {"id": 4,  "name": "Red",           "aliases": ["red"]},
    {"id": 5,  "name": "Dark Pink",     "aliases": ["darkpink", "dark pink"]},
    {"id": 7,  "name": "Light Gray",    "aliases": ["light gray", "lightgray", "lightgrey", "light grey"]},
    {"id": 14, "name": "Yellow",        "aliases": ["yellow"]},
    {"id": 15, "name": "White",         "aliases": ["white"]},
    {"id": 71, "name": "Light Bluish Gray", "aliases": ["light bluish gray", "lightbluishgray"]},
    {"id": 72, "name": "Dark Bluish Gray",  "aliases": ["dark bluish gray", "darkbluishgray"]}
  ]
}
```

Note: the generator script (Step 1) overwrites this with the full list when run. This minimal seed is sufficient for M1 unit tests and lets the backend start without API access.

- [ ] **Step 3: Write failing test**

Create `backend/tests/unit/test_color_table.py`:

```python
from brickfinder.colors.table import ColorTable, load_default


def test_lookup_canonical_name():
    t = ColorTable.from_dict({"colors": [{"id": 4, "name": "Red", "aliases": ["red"]}]})
    assert t.lookup("Red") == 4
    assert t.lookup("red") == 4
    assert t.lookup("RED") == 4


def test_lookup_alias():
    t = ColorTable.from_dict({"colors": [
        {"id": 71, "name": "Light Bluish Gray", "aliases": ["light bluish gray", "lightbluishgray"]}
    ]})
    assert t.lookup("lightbluishgray") == 71
    assert t.lookup("Light Bluish Gray") == 71


def test_lookup_unknown_returns_minus_one():
    t = ColorTable.from_dict({"colors": []})
    assert t.lookup("Magenta") == -1


def test_load_default_includes_red():
    t = load_default()
    assert t.lookup("Red") == 4
```

- [ ] **Step 4: Run, expect failure**

```bash
pytest tests/unit/test_color_table.py -v
```

Expected: ImportError.

- [ ] **Step 5: Implement ColorTable**

Create `backend/src/brickfinder/colors/table.py`:

```python
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

_NORMALIZE_RE = re.compile(r"[^a-z0-9]+")


def _normalize(s: str) -> str:
    return _NORMALIZE_RE.sub(" ", s.lower()).strip()


class ColorTable:
    def __init__(self, name_to_id: dict[str, int]) -> None:
        self._lookup: dict[str, int] = name_to_id

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "ColorTable":
        name_to_id: dict[str, int] = {}
        for entry in data["colors"]:
            cid = int(entry["id"])
            keys = [entry["name"], *entry.get("aliases", [])]
            for k in keys:
                name_to_id[_normalize(k)] = cid
                name_to_id[k.lower().replace(" ", "")] = cid
        return cls(name_to_id)

    def lookup(self, name: str) -> int:
        if not name:
            return -1
        candidates = (_normalize(name), name.lower().replace(" ", ""))
        for c in candidates:
            if c in self._lookup:
                return self._lookup[c]
        return -1


_DEFAULT_PATH = Path(__file__).with_name("colors.json")


def load_default() -> ColorTable:
    return ColorTable.from_dict(json.loads(_DEFAULT_PATH.read_text()))
```

- [ ] **Step 6: Run, expect pass**

```bash
pytest tests/unit/test_color_table.py -v
```

Expected: 4 passed.

- [ ] **Step 7: Commit**

```bash
git add backend/src/brickfinder/colors/ backend/scripts/build_color_table.py
git add backend/tests/unit/test_color_table.py
git commit -m "feat(backend): color name lookup with alias normalization"
```

---

### Task 6: Circuit breaker primitive

**Files:**
- Create: `backend/src/brickfinder/upstream/__init__.py`
- Create: `backend/src/brickfinder/upstream/breaker.py`
- Create: `backend/tests/unit/test_breaker.py`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `class CircuitBreaker` with `__init__(self, *, threshold: int, cooldown_seconds: float, clock: Callable[[], float] = time.monotonic)`.
  - `breaker.allow() -> bool` — returns False if open.
  - `breaker.record_success() -> None` — resets failure counter.
  - `breaker.record_failure() -> None` — increments counter; opens at threshold.
  - `class CircuitOpenError(Exception)` raised when `allow()` returns False and the caller wants a typed error.

- [ ] **Step 1: Write failing test**

Create `backend/tests/unit/test_breaker.py`:

```python
import pytest

from brickfinder.upstream.breaker import CircuitBreaker, CircuitOpenError


class FakeClock:
    def __init__(self) -> None:
        self.now = 0.0

    def __call__(self) -> float:
        return self.now


def test_breaker_opens_after_threshold():
    clock = FakeClock()
    cb = CircuitBreaker(threshold=3, cooldown_seconds=10, clock=clock)
    assert cb.allow()
    for _ in range(3):
        cb.record_failure()
    assert not cb.allow()


def test_breaker_closes_after_cooldown():
    clock = FakeClock()
    cb = CircuitBreaker(threshold=2, cooldown_seconds=10, clock=clock)
    cb.record_failure(); cb.record_failure()
    assert not cb.allow()
    clock.now = 11
    assert cb.allow()


def test_success_resets_counter():
    clock = FakeClock()
    cb = CircuitBreaker(threshold=3, cooldown_seconds=10, clock=clock)
    cb.record_failure(); cb.record_failure()
    cb.record_success()
    cb.record_failure(); cb.record_failure()
    assert cb.allow()


def test_circuit_open_error_raised_via_helper():
    clock = FakeClock()
    cb = CircuitBreaker(threshold=1, cooldown_seconds=10, clock=clock)
    cb.record_failure()
    with pytest.raises(CircuitOpenError):
        cb.check_or_raise()
```

- [ ] **Step 2: Run, expect failure**

```bash
pytest tests/unit/test_breaker.py -v
```

Expected: ImportError.

- [ ] **Step 3: Implement**

Create `backend/src/brickfinder/upstream/__init__.py` (empty).

Create `backend/src/brickfinder/upstream/breaker.py`:

```python
from __future__ import annotations

import time
from collections.abc import Callable


class CircuitOpenError(Exception):
    pass


class CircuitBreaker:
    def __init__(
        self,
        *,
        threshold: int,
        cooldown_seconds: float,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._threshold = threshold
        self._cooldown = cooldown_seconds
        self._clock = clock
        self._fail_count = 0
        self._opened_at: float | None = None

    def allow(self) -> bool:
        if self._opened_at is None:
            return True
        if self._clock() - self._opened_at >= self._cooldown:
            # Half-open: allow one probe by resetting state.
            self._opened_at = None
            self._fail_count = 0
            return True
        return False

    def record_success(self) -> None:
        self._fail_count = 0
        self._opened_at = None

    def record_failure(self) -> None:
        self._fail_count += 1
        if self._fail_count >= self._threshold:
            self._opened_at = self._clock()

    def check_or_raise(self) -> None:
        if not self.allow():
            raise CircuitOpenError("circuit open")
```

- [ ] **Step 4: Run, expect pass**

```bash
pytest tests/unit/test_breaker.py -v
```

Expected: 4 passed.

- [ ] **Step 5: Commit**

```bash
git add backend/src/brickfinder/upstream/breaker.py backend/src/brickfinder/upstream/__init__.py
git add backend/tests/unit/test_breaker.py
git commit -m "feat(backend): circuit breaker with cooldown"
```

---

### Task 7: Redis cache wrapper

**Files:**
- Create: `backend/src/brickfinder/cache/__init__.py`
- Create: `backend/src/brickfinder/cache/redis_cache.py`
- Create: `backend/tests/unit/test_cache.py`

**Interfaces:**
- Consumes: `redis.asyncio.Redis` instance
- Produces:
  - `class RedisCache` with `async get_json(self, key: str) -> Any | None` and `async set_json(self, key: str, value: Any, *, ttl_seconds: int | None) -> None`.
  - `def hash_bytes(data: bytes) -> str` — returns sha256 hex.
  - `def hash_text(text: str) -> str` — sha256 of utf-8 encoded text.
  - Key constants: `RECOG_IMG_PREFIX = "recog:img:"`, TTL `RECOG_TTL_SECONDS = 7 * 24 * 3600`.

- [ ] **Step 1: Write failing test**

Create `backend/tests/unit/test_cache.py`:

```python
import pytest

from brickfinder.cache.redis_cache import (
    RECOG_IMG_PREFIX,
    RECOG_TTL_SECONDS,
    RedisCache,
    hash_bytes,
    hash_text,
)


def test_hash_bytes_stable_and_hex():
    h = hash_bytes(b"hello")
    assert h == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"


def test_hash_text_equals_hash_bytes_utf8():
    assert hash_text("héllo") == hash_bytes("héllo".encode("utf-8"))


class FakeRedis:
    def __init__(self) -> None:
        self.store: dict[str, tuple[bytes, int | None]] = {}

    async def get(self, key: str) -> bytes | None:
        return self.store.get(key, (None, None))[0]

    async def set(self, key: str, value: bytes, ex: int | None = None) -> None:
        self.store[key] = (value, ex)


@pytest.mark.asyncio
async def test_set_and_get_json():
    cache = RedisCache(FakeRedis())  # type: ignore[arg-type]
    await cache.set_json("k", {"parts": [{"part_num": "3001"}]}, ttl_seconds=60)
    got = await cache.get_json("k")
    assert got == {"parts": [{"part_num": "3001"}]}


@pytest.mark.asyncio
async def test_miss_returns_none():
    cache = RedisCache(FakeRedis())  # type: ignore[arg-type]
    assert await cache.get_json("missing") is None


def test_constants():
    assert RECOG_IMG_PREFIX == "recog:img:"
    assert RECOG_TTL_SECONDS == 7 * 24 * 3600
```

- [ ] **Step 2: Run, expect failure**

```bash
pytest tests/unit/test_cache.py -v
```

Expected: ImportError.

- [ ] **Step 3: Implement**

Create `backend/src/brickfinder/cache/__init__.py` (empty).

Create `backend/src/brickfinder/cache/redis_cache.py`:

```python
from __future__ import annotations

import hashlib
import json
from typing import Any, Protocol


RECOG_IMG_PREFIX = "recog:img:"
RECOG_TTL_SECONDS = 7 * 24 * 3600


def hash_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def hash_text(text: str) -> str:
    return hash_bytes(text.encode("utf-8"))


class _RedisLike(Protocol):
    async def get(self, key: str) -> bytes | None: ...
    async def set(self, key: str, value: bytes, ex: int | None = None) -> None: ...


class RedisCache:
    def __init__(self, redis: _RedisLike) -> None:
        self._redis = redis

    async def get_json(self, key: str) -> Any | None:
        raw = await self._redis.get(key)
        if raw is None:
            return None
        return json.loads(raw)

    async def set_json(self, key: str, value: Any, *, ttl_seconds: int | None) -> None:
        payload = json.dumps(value, separators=(",", ":"), sort_keys=True).encode("utf-8")
        await self._redis.set(key, payload, ex=ttl_seconds)
```

- [ ] **Step 4: Run, expect pass**

```bash
pytest tests/unit/test_cache.py -v
```

Expected: 5 passed.

- [ ] **Step 5: Commit**

```bash
git add backend/src/brickfinder/cache/ backend/tests/unit/test_cache.py
git commit -m "feat(backend): typed JSON cache wrapper with sha256 helpers"
```

---

### Task 8: Database models + Alembic baseline

**Files:**
- Create: `backend/src/brickfinder/db/__init__.py`
- Create: `backend/src/brickfinder/db/models.py`
- Create: `backend/src/brickfinder/db/engine.py`
- Create: `backend/alembic.ini`
- Create: `backend/alembic/env.py`
- Create: `backend/alembic/script.py.mako`
- Create: `backend/alembic/versions/0001_initial.py`

**Interfaces:**
- Consumes: `Settings.database_url`
- Produces:
  - `class Base(DeclarativeBase)`
  - `class RateQuota(Base)` — columns: `client_key str PK`, `recognize_count int=0`, `match_count int=0`, `translate_count int=0`, `window_start datetime`.
  - `class ApiCallLog(Base)` — columns: `id bigserial PK`, `ts datetime default now()`, `route str`, `cache_hit bool`, `upstream_status int|None`, `latency_ms int|None`.
  - `create_engine_and_sessionmaker(url: str) -> tuple[AsyncEngine, async_sessionmaker[AsyncSession]]`.

- [ ] **Step 1: Create models**

Create `backend/src/brickfinder/db/__init__.py` (empty).

Create `backend/src/brickfinder/db/models.py`:

```python
from __future__ import annotations

from datetime import datetime

from sqlalchemy import BigInteger, Boolean, DateTime, Integer, String, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class RateQuota(Base):
    __tablename__ = "rate_quota"

    client_key: Mapped[str] = mapped_column(String, primary_key=True)
    recognize_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    match_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    translate_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    window_start: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class ApiCallLog(Base):
    __tablename__ = "api_call_log"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    ts: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    route: Mapped[str] = mapped_column(String, nullable=False)
    cache_hit: Mapped[bool] = mapped_column(Boolean, nullable=False)
    upstream_status: Mapped[int | None] = mapped_column(Integer, nullable=True)
    latency_ms: Mapped[int | None] = mapped_column(Integer, nullable=True)
```

- [ ] **Step 2: Create engine factory**

Create `backend/src/brickfinder/db/engine.py`:

```python
from __future__ import annotations

from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker, create_async_engine


def create_engine_and_sessionmaker(
    url: str,
) -> tuple[AsyncEngine, async_sessionmaker[AsyncSession]]:
    engine = create_async_engine(url, future=True, pool_pre_ping=True)
    sm = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)
    return engine, sm
```

- [ ] **Step 3: Initialize Alembic**

Run from `backend/`:

```bash
alembic init alembic
```

This creates `alembic.ini`, `alembic/env.py`, `alembic/script.py.mako`, and `alembic/versions/`.

- [ ] **Step 4: Configure Alembic for async + our models**

Replace `backend/alembic/env.py` with:

```python
from __future__ import annotations

import asyncio
from logging.config import fileConfig

from alembic import context
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import create_async_engine

from brickfinder.config import get_settings
from brickfinder.db.models import Base

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def _db_url() -> str:
    return get_settings().database_url


def run_migrations_offline() -> None:
    context.configure(
        url=_db_url(),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def _run_sync(connection: Connection) -> None:
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()


async def run_migrations_online() -> None:
    engine = create_async_engine(_db_url())
    async with engine.connect() as connection:
        await connection.run_sync(_run_sync)
    await engine.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    asyncio.run(run_migrations_online())
```

- [ ] **Step 5: Generate the baseline revision**

Run from `backend/` with Postgres + Redis running (use docker-compose from Task 14 — but for now you can `pg_dump` `CREATE DATABASE brickfinder;` against any local Postgres):

```bash
DATABASE_URL=postgresql+asyncpg://brickfinder:brickfinder@localhost:5432/brickfinder \
REDIS_URL=redis://localhost:6379/0 \
alembic revision --autogenerate -m "initial"
```

Then rename the file to `backend/alembic/versions/0001_initial.py` and verify it contains `op.create_table('rate_quota', ...)` and `op.create_table('api_call_log', ...)`.

If you can't run autogenerate yet (Postgres not up), hand-write `backend/alembic/versions/0001_initial.py`:

```python
"""initial

Revision ID: 0001
Revises:
Create Date: 2026-06-21

"""
from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "rate_quota",
        sa.Column("client_key", sa.String(), primary_key=True),
        sa.Column("recognize_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("match_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("translate_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("window_start", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_table(
        "api_call_log",
        sa.Column("id", sa.BigInteger(), primary_key=True, autoincrement=True),
        sa.Column(
            "ts", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.Column("route", sa.String(), nullable=False),
        sa.Column("cache_hit", sa.Boolean(), nullable=False),
        sa.Column("upstream_status", sa.Integer(), nullable=True),
        sa.Column("latency_ms", sa.Integer(), nullable=True),
    )


def downgrade() -> None:
    op.drop_table("api_call_log")
    op.drop_table("rate_quota")
```

- [ ] **Step 6: Verify mypy and ruff still pass**

```bash
ruff check . && mypy src
```

Expected: exit 0.

- [ ] **Step 7: Commit**

```bash
git add backend/alembic.ini backend/alembic/ backend/src/brickfinder/db/
git commit -m "feat(backend): db models and alembic baseline"
```

---

### Task 9: Rate limit (rolling 24h window)

**Files:**
- Create: `backend/src/brickfinder/quota/__init__.py`
- Create: `backend/src/brickfinder/quota/rate_limit.py`
- Create: `backend/tests/unit/test_rate_limit.py`

**Interfaces:**
- Consumes: an `AsyncSession` from `db.engine`
- Produces:
  - `class RateLimiter` with `async check_and_bump(self, session: AsyncSession, *, client_key: str, route: str, limit_per_day: int, now: datetime) -> int` — returns the new count after bumping; raises `AppError(RATE_LIMITED, retry_after_seconds=...)` if over.
  - `route` must be one of `"recognize"`, `"match"`, `"translate"` — bumps the matching column.
  - Window: rolling 24 hours. If `now - window_start >= 24h`, reset all counters and set `window_start = now` before bumping.

- [ ] **Step 1: Write failing test**

Create `backend/tests/unit/test_rate_limit.py`:

```python
from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy.ext.asyncio import AsyncEngine, async_sessionmaker, create_async_engine

from brickfinder.db.models import Base, RateQuota
from brickfinder.errors import AppError
from brickfinder.quota.rate_limit import RateLimiter
from brickfinder.schemas.common import ErrorCode


@pytest.fixture
async def sm():
    engine: AsyncEngine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield async_sessionmaker(engine, expire_on_commit=False)
    await engine.dispose()


@pytest.mark.asyncio
async def test_first_call_creates_row_and_returns_one(sm):
    rl = RateLimiter()
    now = datetime(2026, 6, 21, 12, 0, tzinfo=timezone.utc)
    async with sm() as s:
        count = await rl.check_and_bump(
            s, client_key="ip:1.2.3.4", route="recognize", limit_per_day=10, now=now
        )
        await s.commit()
    assert count == 1


@pytest.mark.asyncio
async def test_under_limit_increments(sm):
    rl = RateLimiter()
    now = datetime(2026, 6, 21, 12, 0, tzinfo=timezone.utc)
    async with sm() as s:
        for _ in range(3):
            await rl.check_and_bump(s, client_key="k", route="recognize", limit_per_day=10, now=now)
        await s.commit()
        row = await s.get(RateQuota, "k")
        assert row is not None
        assert row.recognize_count == 3


@pytest.mark.asyncio
async def test_over_limit_raises(sm):
    rl = RateLimiter()
    now = datetime(2026, 6, 21, 12, 0, tzinfo=timezone.utc)
    async with sm() as s:
        for _ in range(2):
            await rl.check_and_bump(s, client_key="k", route="recognize", limit_per_day=2, now=now)
        await s.commit()
        with pytest.raises(AppError) as ei:
            await rl.check_and_bump(
                s, client_key="k", route="recognize", limit_per_day=2, now=now
            )
        assert ei.value.code == ErrorCode.RATE_LIMITED
        assert ei.value.retry_after_seconds is not None
        assert ei.value.retry_after_seconds > 0


@pytest.mark.asyncio
async def test_window_resets_after_24h(sm):
    rl = RateLimiter()
    t0 = datetime(2026, 6, 21, 12, 0, tzinfo=timezone.utc)
    async with sm() as s:
        for _ in range(5):
            await rl.check_and_bump(s, client_key="k", route="recognize", limit_per_day=5, now=t0)
        await s.commit()

        t1 = t0 + timedelta(hours=24, seconds=1)
        count = await rl.check_and_bump(
            s, client_key="k", route="recognize", limit_per_day=5, now=t1
        )
        await s.commit()
        assert count == 1
```

Note: this test uses SQLite for speed. Add aiosqlite to dev deps if it's not already pulled in.

- [ ] **Step 2: Update dev deps to include aiosqlite**

Edit `backend/pyproject.toml` and add `"aiosqlite>=0.20"` to `[project.optional-dependencies].dev`.

- [ ] **Step 3: Run, expect failure**

```bash
pip install -e ".[dev]"
pytest tests/unit/test_rate_limit.py -v
```

Expected: ImportError.

- [ ] **Step 4: Implement**

Create `backend/src/brickfinder/quota/__init__.py` (empty).

Create `backend/src/brickfinder/quota/rate_limit.py`:

```python
from __future__ import annotations

from datetime import datetime, timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from ..db.models import RateQuota
from ..errors import AppError
from ..schemas.common import ErrorCode

_ROUTE_COLUMNS = {
    "recognize": "recognize_count",
    "match": "match_count",
    "translate": "translate_count",
}

_WINDOW = timedelta(hours=24)


class RateLimiter:
    async def check_and_bump(
        self,
        session: AsyncSession,
        *,
        client_key: str,
        route: str,
        limit_per_day: int,
        now: datetime,
    ) -> int:
        if route not in _ROUTE_COLUMNS:
            raise ValueError(f"unknown route: {route}")
        column = _ROUTE_COLUMNS[route]

        row = await session.get(RateQuota, client_key)
        if row is None:
            row = RateQuota(
                client_key=client_key,
                recognize_count=0,
                match_count=0,
                translate_count=0,
                window_start=now,
            )
            session.add(row)
            await session.flush()
        elif now - row.window_start >= _WINDOW:
            row.recognize_count = 0
            row.match_count = 0
            row.translate_count = 0
            row.window_start = now

        current = getattr(row, column)
        if current >= limit_per_day:
            reset_at = row.window_start + _WINDOW
            retry = max(int((reset_at - now).total_seconds()), 1)
            raise AppError(
                code=ErrorCode.RATE_LIMITED,
                message="Daily quota exceeded",
                http_status=429,
                retry_after_seconds=retry,
            )

        setattr(row, column, current + 1)
        await session.flush()
        return current + 1
```

- [ ] **Step 5: Run, expect pass**

```bash
pytest tests/unit/test_rate_limit.py -v
```

Expected: 4 passed.

- [ ] **Step 6: Commit**

```bash
git add backend/src/brickfinder/quota/ backend/tests/unit/test_rate_limit.py backend/pyproject.toml
git commit -m "feat(backend): rolling 24h rate limit"
```

---

### Task 10: Brickognize async client

**Files:**
- Create: `backend/src/brickfinder/upstream/brickognize.py`
- Create: `backend/tests/unit/test_brickognize_client.py`

**Interfaces:**
- Consumes: `httpx.AsyncClient`, `CircuitBreaker`, `Settings`
- Produces:
  - `class BrickognizeRawItem(BaseModel)`: `id: str`, `name: str | None`, `color: str | None`, `score: float | None` — what the API returns per item, untouched.
  - `class BrickognizeResult(BaseModel)`: `items: list[BrickognizeRawItem]`.
  - `class BrickognizeClient` with `async predict_parts(self, *, image_bytes: bytes, filename: str, content_type: str) -> BrickognizeResult`.
  - Behavior: on `httpx.TimeoutException` raise `AppError(UPSTREAM_TIMEOUT, http_status=504)`; on 5xx or transport error raise `AppError(UPSTREAM_ERROR, http_status=502)`; record on breaker on success/failure; if breaker is open raise `AppError(UPSTREAM_ERROR, http_status=502, message="upstream unavailable")` without making the call.
  - Retries once on timeout/5xx before raising.

- [ ] **Step 1: Write failing test**

Create `backend/tests/unit/test_brickognize_client.py`:

```python
import pytest
import respx
from httpx import AsyncClient, ConnectTimeout, Response

from brickfinder.errors import AppError
from brickfinder.schemas.common import ErrorCode
from brickfinder.upstream.breaker import CircuitBreaker
from brickfinder.upstream.brickognize import BrickognizeClient


@pytest.fixture
def breaker():
    return CircuitBreaker(threshold=3, cooldown_seconds=30)


@pytest.mark.asyncio
async def test_predict_parts_happy_path(breaker):
    async with respx.mock(base_url="https://example.com") as router:
        router.post("/predict/parts/").mock(
            return_value=Response(
                200,
                json={
                    "items": [
                        {"id": "3001", "name": "Brick 2x4", "color": "Red", "score": 0.91},
                        {"id": "3001", "name": "Brick 2x4", "color": "Red", "score": 0.88},
                    ]
                },
            )
        )
        async with AsyncClient() as http:
            client = BrickognizeClient(
                http=http, base_url="https://example.com", timeout=5.0, breaker=breaker
            )
            result = await client.predict_parts(
                image_bytes=b"fake", filename="x.jpg", content_type="image/jpeg"
            )

    assert len(result.items) == 2
    assert result.items[0].id == "3001"


@pytest.mark.asyncio
async def test_upstream_5xx_retries_then_fails(breaker):
    async with respx.mock(base_url="https://example.com") as router:
        route = router.post("/predict/parts/").mock(return_value=Response(503))
        async with AsyncClient() as http:
            client = BrickognizeClient(
                http=http, base_url="https://example.com", timeout=5.0, breaker=breaker
            )
            with pytest.raises(AppError) as ei:
                await client.predict_parts(
                    image_bytes=b"x", filename="x.jpg", content_type="image/jpeg"
                )
    assert ei.value.code == ErrorCode.UPSTREAM_ERROR
    assert route.call_count == 2  # initial + 1 retry


@pytest.mark.asyncio
async def test_timeout_returns_upstream_timeout(breaker):
    async with respx.mock(base_url="https://example.com") as router:
        router.post("/predict/parts/").mock(side_effect=ConnectTimeout("slow"))
        async with AsyncClient() as http:
            client = BrickognizeClient(
                http=http, base_url="https://example.com", timeout=5.0, breaker=breaker
            )
            with pytest.raises(AppError) as ei:
                await client.predict_parts(
                    image_bytes=b"x", filename="x.jpg", content_type="image/jpeg"
                )
    assert ei.value.code == ErrorCode.UPSTREAM_TIMEOUT


@pytest.mark.asyncio
async def test_breaker_open_skips_call():
    cb = CircuitBreaker(threshold=1, cooldown_seconds=30)
    cb.record_failure()  # open

    async with respx.mock(base_url="https://example.com") as router:
        route = router.post("/predict/parts/").mock(return_value=Response(200, json={"items": []}))
        async with AsyncClient() as http:
            client = BrickognizeClient(
                http=http, base_url="https://example.com", timeout=5.0, breaker=cb
            )
            with pytest.raises(AppError) as ei:
                await client.predict_parts(
                    image_bytes=b"x", filename="x.jpg", content_type="image/jpeg"
                )
    assert ei.value.code == ErrorCode.UPSTREAM_ERROR
    assert route.call_count == 0
```

- [ ] **Step 2: Run, expect failure**

```bash
pytest tests/unit/test_brickognize_client.py -v
```

Expected: ImportError.

- [ ] **Step 3: Implement**

Create `backend/src/brickfinder/upstream/brickognize.py`:

```python
from __future__ import annotations

import httpx
from pydantic import BaseModel

from ..errors import AppError
from ..logging import get_logger
from ..schemas.common import ErrorCode
from .breaker import CircuitBreaker

log = get_logger(__name__)

_PATH = "/predict/parts/"
_MAX_ATTEMPTS = 2  # initial + 1 retry


class BrickognizeRawItem(BaseModel):
    id: str
    name: str | None = None
    color: str | None = None
    score: float | None = None


class BrickognizeResult(BaseModel):
    items: list[BrickognizeRawItem]


class BrickognizeClient:
    def __init__(
        self,
        *,
        http: httpx.AsyncClient,
        base_url: str,
        timeout: float,
        breaker: CircuitBreaker,
    ) -> None:
        self._http = http
        self._base = base_url.rstrip("/")
        self._timeout = timeout
        self._breaker = breaker

    async def predict_parts(
        self, *, image_bytes: bytes, filename: str, content_type: str
    ) -> BrickognizeResult:
        if not self._breaker.allow():
            log.warning("brickognize_breaker_open")
            raise AppError(
                code=ErrorCode.UPSTREAM_ERROR,
                message="Recognition service unavailable",
                http_status=502,
            )

        last_exc: BaseException | None = None
        for attempt in range(_MAX_ATTEMPTS):
            try:
                files = {"query_image": (filename, image_bytes, content_type)}
                resp = await self._http.post(
                    f"{self._base}{_PATH}", files=files, timeout=self._timeout
                )
                if resp.status_code >= 500:
                    last_exc = httpx.HTTPStatusError(
                        f"{resp.status_code}", request=resp.request, response=resp
                    )
                    log.warning(
                        "brickognize_5xx", status=resp.status_code, attempt=attempt
                    )
                    continue
                resp.raise_for_status()
                payload = resp.json()
                self._breaker.record_success()
                return BrickognizeResult.model_validate(payload)
            except httpx.TimeoutException as exc:
                last_exc = exc
                log.warning("brickognize_timeout", attempt=attempt)
                continue
            except httpx.HTTPError as exc:
                last_exc = exc
                log.warning("brickognize_http_error", attempt=attempt, error=repr(exc))
                continue

        self._breaker.record_failure()
        if isinstance(last_exc, httpx.TimeoutException):
            raise AppError(
                code=ErrorCode.UPSTREAM_TIMEOUT,
                message="Recognition service timed out",
                http_status=504,
            )
        raise AppError(
            code=ErrorCode.UPSTREAM_ERROR,
            message="Recognition service error",
            http_status=502,
        )
```

- [ ] **Step 4: Run, expect pass**

```bash
pytest tests/unit/test_brickognize_client.py -v
```

Expected: 4 passed.

- [ ] **Step 5: Commit**

```bash
git add backend/src/brickfinder/upstream/brickognize.py
git add backend/tests/unit/test_brickognize_client.py
git commit -m "feat(backend): Brickognize client with retry and breaker"
```

---

### Task 11: Recognize response schema and RecognizeService

**Files:**
- Create: `backend/src/brickfinder/schemas/recognize.py`
- Create: `backend/src/brickfinder/services/__init__.py`
- Create: `backend/src/brickfinder/services/recognize.py`
- Create: `backend/tests/unit/test_recognize_service.py`

**Interfaces:**
- Consumes: `BrickognizeClient`, `RedisCache`, `ColorTable`, `AsyncSession`, `RateLimiter`, `Settings`
- Produces:
  - `class PartItem(BaseModel)`: `part_num: str`, `color_id: int`, `quantity: int`, `confidence: float | None`.
  - `class RecognizeResponse(BaseModel)`: `parts: list[PartItem]`, `cache_hit: bool`, `low_confidence_count: int`.
  - `class RecognizeService` with method `async recognize(self, session: AsyncSession, *, image_bytes: bytes, filename: str, content_type: str, client_key: str, now: datetime) -> RecognizeResponse`.
  - Pipeline: (1) rate-limit bump; (2) sha256(image) → cache lookup; (3) on miss call Brickognize; (4) normalize: color name → color_id (-1 if unknown), aggregate by `(part_num, color_id)` summing quantities and averaging confidence; (5) write cache with `RECOG_TTL_SECONDS`; (6) record `api_call_log` row with cache_hit + latency.
  - On `AppError` from rate-limit or upstream client, the row in `api_call_log` is still written (cache_hit=false, upstream_status=None or 5xx) — implementation MUST wrap the upstream call so the log row is always emitted.

- [ ] **Step 1: Write the response schema**

Create `backend/src/brickfinder/schemas/recognize.py`:

```python
from __future__ import annotations

from pydantic import BaseModel, Field


class PartItem(BaseModel):
    part_num: str
    color_id: int = Field(description="Rebrickable color id; -1 if unknown")
    quantity: int = Field(ge=1)
    confidence: float | None = Field(default=None, ge=0.0, le=1.0)


class RecognizeResponse(BaseModel):
    parts: list[PartItem]
    cache_hit: bool
    low_confidence_count: int
```

- [ ] **Step 2: Write failing service test**

Create `backend/tests/unit/test_recognize_service.py`:

```python
from datetime import datetime, timezone
from typing import Any

import pytest
from sqlalchemy.ext.asyncio import AsyncEngine, async_sessionmaker, create_async_engine

from brickfinder.cache.redis_cache import RECOG_IMG_PREFIX, RedisCache, hash_bytes
from brickfinder.colors.table import ColorTable
from brickfinder.db.models import ApiCallLog, Base
from brickfinder.errors import AppError
from brickfinder.quota.rate_limit import RateLimiter
from brickfinder.schemas.common import ErrorCode
from brickfinder.services.recognize import RecognizeService
from brickfinder.upstream.brickognize import BrickognizeRawItem, BrickognizeResult


class FakeRedis:
    def __init__(self) -> None:
        self.store: dict[str, tuple[bytes, int | None]] = {}

    async def get(self, key: str) -> bytes | None:
        return self.store.get(key, (None, None))[0]

    async def set(self, key: str, value: bytes, ex: int | None = None) -> None:
        self.store[key] = (value, ex)


class FakeBrickognize:
    def __init__(self, result: BrickognizeResult | None = None, exc: BaseException | None = None) -> None:
        self.result = result
        self.exc = exc
        self.calls: list[tuple[bytes, str, str]] = []

    async def predict_parts(
        self, *, image_bytes: bytes, filename: str, content_type: str
    ) -> BrickognizeResult:
        self.calls.append((image_bytes, filename, content_type))
        if self.exc is not None:
            raise self.exc
        assert self.result is not None
        return self.result


@pytest.fixture
def color_table():
    return ColorTable.from_dict(
        {
            "colors": [
                {"id": 4, "name": "Red", "aliases": ["red"]},
                {"id": 14, "name": "Yellow", "aliases": ["yellow"]},
            ]
        }
    )


@pytest.fixture
async def sm():
    engine: AsyncEngine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield async_sessionmaker(engine, expire_on_commit=False)
    await engine.dispose()


def _now() -> datetime:
    return datetime(2026, 6, 21, 12, 0, tzinfo=timezone.utc)


@pytest.mark.asyncio
async def test_recognize_aggregates_same_part_color(sm, color_table):
    bk = FakeBrickognize(
        BrickognizeResult.model_validate(
            {
                "items": [
                    {"id": "3001", "name": "Brick 2x4", "color": "Red", "score": 0.9},
                    {"id": "3001", "name": "Brick 2x4", "color": "Red", "score": 0.7},
                    {"id": "3001", "name": "Brick 2x4", "color": "Yellow", "score": 0.8},
                ]
            }
        )
    )
    cache = RedisCache(FakeRedis())  # type: ignore[arg-type]
    svc = RecognizeService(
        brickognize=bk,
        cache=cache,
        colors=color_table,
        rate_limiter=RateLimiter(),
        recognize_limit_per_day=100,
        low_confidence_threshold=0.6,
    )
    async with sm() as s:
        resp = await svc.recognize(
            s,
            image_bytes=b"img",
            filename="a.jpg",
            content_type="image/jpeg",
            client_key="ip:1",
            now=_now(),
        )
        await s.commit()

    assert resp.cache_hit is False
    parts = {(p.part_num, p.color_id): p for p in resp.parts}
    assert parts[("3001", 4)].quantity == 2
    assert parts[("3001", 4)].confidence == pytest.approx(0.8, rel=1e-3)
    assert parts[("3001", 14)].quantity == 1


@pytest.mark.asyncio
async def test_unknown_color_becomes_minus_one(sm, color_table):
    bk = FakeBrickognize(
        BrickognizeResult.model_validate(
            {"items": [{"id": "3001", "color": "Magenta", "score": 0.5}]}
        )
    )
    cache = RedisCache(FakeRedis())  # type: ignore[arg-type]
    svc = RecognizeService(
        brickognize=bk,
        cache=cache,
        colors=color_table,
        rate_limiter=RateLimiter(),
        recognize_limit_per_day=100,
        low_confidence_threshold=0.6,
    )
    async with sm() as s:
        resp = await svc.recognize(
            s,
            image_bytes=b"img",
            filename="a.jpg",
            content_type="image/jpeg",
            client_key="ip:1",
            now=_now(),
        )
        await s.commit()
    assert resp.parts[0].color_id == -1
    assert resp.low_confidence_count == 1


@pytest.mark.asyncio
async def test_cache_hit_skips_upstream(sm, color_table):
    cache_redis = FakeRedis()
    cached_payload = {
        "parts": [{"part_num": "3001", "color_id": 4, "quantity": 5, "confidence": 0.9}],
        "low_confidence_count": 0,
    }
    import json as _j
    cache_redis.store[RECOG_IMG_PREFIX + hash_bytes(b"img")] = (
        _j.dumps(cached_payload).encode(), None
    )
    bk = FakeBrickognize()  # no result; should not be called
    svc = RecognizeService(
        brickognize=bk,
        cache=RedisCache(cache_redis),  # type: ignore[arg-type]
        colors=color_table,
        rate_limiter=RateLimiter(),
        recognize_limit_per_day=100,
        low_confidence_threshold=0.6,
    )
    async with sm() as s:
        resp = await svc.recognize(
            s,
            image_bytes=b"img",
            filename="a.jpg",
            content_type="image/jpeg",
            client_key="ip:1",
            now=_now(),
        )
        await s.commit()
    assert resp.cache_hit is True
    assert bk.calls == []
    assert resp.parts[0].quantity == 5


@pytest.mark.asyncio
async def test_rate_limit_raises(sm, color_table):
    bk = FakeBrickognize(BrickognizeResult.model_validate({"items": []}))
    svc = RecognizeService(
        brickognize=bk,
        cache=RedisCache(FakeRedis()),  # type: ignore[arg-type]
        colors=color_table,
        rate_limiter=RateLimiter(),
        recognize_limit_per_day=1,
        low_confidence_threshold=0.6,
    )
    async with sm() as s:
        await svc.recognize(
            s,
            image_bytes=b"a",
            filename="a.jpg",
            content_type="image/jpeg",
            client_key="ip:1",
            now=_now(),
        )
        with pytest.raises(AppError) as ei:
            await svc.recognize(
                s,
                image_bytes=b"b",
                filename="b.jpg",
                content_type="image/jpeg",
                client_key="ip:1",
                now=_now(),
            )
    assert ei.value.code == ErrorCode.RATE_LIMITED


@pytest.mark.asyncio
async def test_api_call_log_written_on_success(sm, color_table):
    bk = FakeBrickognize(BrickognizeResult.model_validate({"items": []}))
    svc = RecognizeService(
        brickognize=bk,
        cache=RedisCache(FakeRedis()),  # type: ignore[arg-type]
        colors=color_table,
        rate_limiter=RateLimiter(),
        recognize_limit_per_day=100,
        low_confidence_threshold=0.6,
    )
    async with sm() as s:
        await svc.recognize(
            s,
            image_bytes=b"x",
            filename="a.jpg",
            content_type="image/jpeg",
            client_key="ip:1",
            now=_now(),
        )
        await s.commit()
        rows = (await s.execute(__import__("sqlalchemy").select(ApiCallLog))).scalars().all()
    assert len(rows) == 1
    assert rows[0].route == "recognize"
    assert rows[0].cache_hit is False
```

- [ ] **Step 3: Run, expect failure**

```bash
pytest tests/unit/test_recognize_service.py -v
```

Expected: ImportError.

- [ ] **Step 4: Implement RecognizeService**

Create `backend/src/brickfinder/services/__init__.py` (empty).

Create `backend/src/brickfinder/services/recognize.py`:

```python
from __future__ import annotations

import time
from collections import defaultdict
from datetime import datetime
from typing import Protocol

from sqlalchemy.ext.asyncio import AsyncSession

from ..cache.redis_cache import (
    RECOG_IMG_PREFIX,
    RECOG_TTL_SECONDS,
    RedisCache,
    hash_bytes,
)
from ..colors.table import ColorTable
from ..db.models import ApiCallLog
from ..errors import AppError
from ..logging import get_logger
from ..quota.rate_limit import RateLimiter
from ..schemas.recognize import PartItem, RecognizeResponse
from ..upstream.brickognize import BrickognizeResult

log = get_logger(__name__)


class _BrickognizeLike(Protocol):
    async def predict_parts(
        self, *, image_bytes: bytes, filename: str, content_type: str
    ) -> BrickognizeResult: ...


class RecognizeService:
    def __init__(
        self,
        *,
        brickognize: _BrickognizeLike,
        cache: RedisCache,
        colors: ColorTable,
        rate_limiter: RateLimiter,
        recognize_limit_per_day: int,
        low_confidence_threshold: float = 0.6,
    ) -> None:
        self._brickognize = brickognize
        self._cache = cache
        self._colors = colors
        self._rate_limiter = rate_limiter
        self._limit = recognize_limit_per_day
        self._low_conf = low_confidence_threshold

    async def recognize(
        self,
        session: AsyncSession,
        *,
        image_bytes: bytes,
        filename: str,
        content_type: str,
        client_key: str,
        now: datetime,
    ) -> RecognizeResponse:
        started = time.monotonic()
        upstream_status: int | None = None
        cache_hit = False

        try:
            await self._rate_limiter.check_and_bump(
                session,
                client_key=client_key,
                route="recognize",
                limit_per_day=self._limit,
                now=now,
            )

            digest = hash_bytes(image_bytes)
            cache_key = RECOG_IMG_PREFIX + digest
            cached = await self._cache.get_json(cache_key)
            if cached is not None:
                cache_hit = True
                return RecognizeResponse(
                    parts=[PartItem(**p) for p in cached["parts"]],
                    cache_hit=True,
                    low_confidence_count=int(cached.get("low_confidence_count", 0)),
                )

            result = await self._brickognize.predict_parts(
                image_bytes=image_bytes, filename=filename, content_type=content_type
            )
            upstream_status = 200

            parts = self._normalize(result)
            low_conf = sum(1 for p in parts if p.confidence is not None and p.confidence < self._low_conf)

            await self._cache.set_json(
                cache_key,
                {
                    "parts": [p.model_dump() for p in parts],
                    "low_confidence_count": low_conf,
                },
                ttl_seconds=RECOG_TTL_SECONDS,
            )
            return RecognizeResponse(parts=parts, cache_hit=False, low_confidence_count=low_conf)

        except AppError as exc:
            upstream_status = exc.http_status if exc.http_status >= 500 else None
            raise
        finally:
            session.add(
                ApiCallLog(
                    route="recognize",
                    cache_hit=cache_hit,
                    upstream_status=upstream_status,
                    latency_ms=int((time.monotonic() - started) * 1000),
                )
            )

    def _normalize(self, result: BrickognizeResult) -> list[PartItem]:
        groups: dict[tuple[str, int], list[float]] = defaultdict(list)
        for item in result.items:
            color_id = self._colors.lookup(item.color or "")
            key = (item.id, color_id)
            if item.score is not None:
                groups[key].append(item.score)
            else:
                groups[key].append(0.0)
        parts: list[PartItem] = []
        for (part_num, color_id), scores in groups.items():
            avg = sum(scores) / len(scores) if scores else None
            parts.append(
                PartItem(
                    part_num=part_num,
                    color_id=color_id,
                    quantity=len(scores),
                    confidence=avg,
                )
            )
        parts.sort(key=lambda p: (p.part_num, p.color_id))
        return parts
```

- [ ] **Step 5: Run, expect pass**

```bash
pytest tests/unit/test_recognize_service.py -v
```

Expected: 5 passed.

- [ ] **Step 6: Commit**

```bash
git add backend/src/brickfinder/schemas/recognize.py
git add backend/src/brickfinder/services/
git add backend/tests/unit/test_recognize_service.py
git commit -m "feat(backend): RecognizeService with cache, rate limit, normalization"
```

---

### Task 12: FastAPI deps + route + app factory

**Files:**
- Create: `backend/src/brickfinder/deps.py`
- Create: `backend/src/brickfinder/routes/__init__.py`
- Create: `backend/src/brickfinder/routes/health.py`
- Create: `backend/src/brickfinder/routes/recognize.py`
- Create: `backend/src/brickfinder/main.py`

**Interfaces:**
- Consumes: all earlier components
- Produces:
  - `app = create_app()` FastAPI instance.
  - `GET /health` → `{"status": "ok"}` (200).
  - `POST /v1/recognize` accepts `multipart/form-data` with field `image`. Validates content-type starts with `image/`. Reads bytes into memory; checks `<= upload_max_bytes`. Resolves `client_key` from `X-Client-Id` header if present, else `f"ip:{request.client.host}"`. Returns `RecognizeResponse`.
  - Dependency functions: `get_db_session()`, `get_redis()`, `get_recognize_service()`, `get_client_key(request)`.

- [ ] **Step 1: Create deps.py**

Create `backend/src/brickfinder/deps.py`:

```python
from __future__ import annotations

from collections.abc import AsyncIterator
from datetime import datetime, timezone
from functools import lru_cache

import httpx
from fastapi import Depends, Request
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from .cache.redis_cache import RedisCache
from .colors.table import ColorTable, load_default
from .config import Settings, get_settings
from .db.engine import create_engine_and_sessionmaker
from .quota.rate_limit import RateLimiter
from .services.recognize import RecognizeService
from .upstream.breaker import CircuitBreaker
from .upstream.brickognize import BrickognizeClient


@lru_cache(maxsize=1)
def _engine_and_sm() -> async_sessionmaker[AsyncSession]:
    _, sm = create_engine_and_sessionmaker(get_settings().database_url)
    return sm


@lru_cache(maxsize=1)
def _redis() -> Redis:
    return Redis.from_url(get_settings().redis_url, decode_responses=False)


@lru_cache(maxsize=1)
def _http() -> httpx.AsyncClient:
    return httpx.AsyncClient()


@lru_cache(maxsize=1)
def _breaker() -> CircuitBreaker:
    s = get_settings()
    return CircuitBreaker(
        threshold=s.circuit_breaker_threshold,
        cooldown_seconds=s.circuit_breaker_cooldown_seconds,
    )


@lru_cache(maxsize=1)
def _colors() -> ColorTable:
    return load_default()


@lru_cache(maxsize=1)
def _rate_limiter() -> RateLimiter:
    return RateLimiter()


async def get_db_session() -> AsyncIterator[AsyncSession]:
    sm = _engine_and_sm()
    async with sm() as session:
        yield session


def get_settings_dep() -> Settings:
    return get_settings()


def get_recognize_service(
    settings: Settings = Depends(get_settings_dep),
) -> RecognizeService:
    client = BrickognizeClient(
        http=_http(),
        base_url=settings.brickognize_base_url,
        timeout=settings.brickognize_timeout_seconds,
        breaker=_breaker(),
    )
    return RecognizeService(
        brickognize=client,
        cache=RedisCache(_redis()),
        colors=_colors(),
        rate_limiter=_rate_limiter(),
        recognize_limit_per_day=settings.rate_limit_recognize_per_day,
    )


def get_client_key(request: Request) -> str:
    header = request.headers.get("X-Client-Id")
    if header:
        return f"dev:{header[:64]}"
    host = request.client.host if request.client else "unknown"
    return f"ip:{host}"


def utcnow() -> datetime:
    return datetime.now(tz=timezone.utc)
```

- [ ] **Step 2: Create health route**

Create `backend/src/brickfinder/routes/__init__.py` (empty).

Create `backend/src/brickfinder/routes/health.py`:

```python
from fastapi import APIRouter

router = APIRouter()


@router.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
```

- [ ] **Step 3: Create recognize route**

Create `backend/src/brickfinder/routes/recognize.py`:

```python
from __future__ import annotations

from fastapi import APIRouter, Depends, File, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import Settings
from ..deps import (
    get_client_key,
    get_db_session,
    get_recognize_service,
    get_settings_dep,
    utcnow,
)
from ..errors import AppError
from ..schemas.common import ErrorCode
from ..schemas.recognize import RecognizeResponse
from ..services.recognize import RecognizeService

router = APIRouter(prefix="/v1")

_ALLOWED_PREFIX = "image/"


@router.post("/recognize", response_model=RecognizeResponse)
async def recognize(
    image: UploadFile = File(...),
    session: AsyncSession = Depends(get_db_session),
    service: RecognizeService = Depends(get_recognize_service),
    client_key: str = Depends(get_client_key),
    settings: Settings = Depends(get_settings_dep),
) -> RecognizeResponse:
    if not (image.content_type or "").startswith(_ALLOWED_PREFIX):
        raise AppError(
            code=ErrorCode.INVALID_INPUT,
            message="image content-type must be image/*",
            http_status=400,
        )

    data = await image.read()
    try:
        if len(data) == 0:
            raise AppError(
                code=ErrorCode.INVALID_INPUT,
                message="empty image",
                http_status=400,
            )
        if len(data) > settings.upload_max_bytes:
            raise AppError(
                code=ErrorCode.INVALID_INPUT,
                message=f"image exceeds {settings.upload_max_bytes} bytes",
                http_status=400,
            )

        response = await service.recognize(
            session,
            image_bytes=data,
            filename=image.filename or "upload.jpg",
            content_type=image.content_type or "image/jpeg",
            client_key=client_key,
            now=utcnow(),
        )
        await session.commit()
        return response
    finally:
        await image.close()
```

- [ ] **Step 4: Create main.py**

Create `backend/src/brickfinder/main.py`:

```python
from __future__ import annotations

from contextlib import asynccontextmanager
from collections.abc import AsyncIterator

from fastapi import FastAPI

from .config import get_settings
from .errors import register_exception_handlers
from .logging import configure_logging
from .routes import health, recognize


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    configure_logging(get_settings())
    yield


def create_app() -> FastAPI:
    app = FastAPI(title="brickfinder", lifespan=lifespan)
    register_exception_handlers(app)
    app.include_router(health.router)
    app.include_router(recognize.router)
    return app


app = create_app()
```

- [ ] **Step 5: Verify lint + types**

```bash
ruff check . && mypy src
```

Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add backend/src/brickfinder/deps.py backend/src/brickfinder/routes/ backend/src/brickfinder/main.py
git commit -m "feat(backend): routes, deps, app factory"
```

---

### Task 13: Integration tests for health and recognize

**Files:**
- Create: `backend/tests/conftest.py`
- Create: `backend/tests/integration/__init__.py`
- Create: `backend/tests/integration/test_health.py`
- Create: `backend/tests/integration/test_recognize_route.py`

**Interfaces:**
- Consumes: testcontainers for Postgres + Redis, respx for Brickognize mocking.
- Produces: 4+ integration tests that boot the real FastAPI app against ephemeral Postgres + Redis.

- [ ] **Step 1: Create conftest with containers**

Create `backend/tests/conftest.py`:

```python
from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator, Iterator

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import create_async_engine
from testcontainers.postgres import PostgresContainer
from testcontainers.redis import RedisContainer

from brickfinder.config import get_settings
from brickfinder.db.models import Base


@pytest.fixture(scope="session")
def postgres() -> Iterator[PostgresContainer]:
    with PostgresContainer("postgres:16-alpine") as pg:
        yield pg


@pytest.fixture(scope="session")
def redis_container() -> Iterator[RedisContainer]:
    with RedisContainer("redis:7-alpine") as r:
        yield r


@pytest.fixture(scope="session", autouse=True)
def configure_env(postgres, redis_container, monkeypatch_session) -> None:
    raw = postgres.get_connection_url()
    # testcontainers returns psycopg2 url; convert to asyncpg
    url = raw.replace("postgresql+psycopg2://", "postgresql+asyncpg://").replace(
        "postgresql://", "postgresql+asyncpg://"
    )
    redis_url = f"redis://{redis_container.get_container_host_ip()}:{redis_container.get_exposed_port(6379)}/0"

    monkeypatch_session.setenv("DATABASE_URL", url)
    monkeypatch_session.setenv("REDIS_URL", redis_url)
    monkeypatch_session.setenv("BRICKOGNIZE_BASE_URL", "http://brickognize.test")
    monkeypatch_session.setenv("BRICKOGNIZE_TIMEOUT_SECONDS", "2")
    monkeypatch_session.setenv("RATE_LIMIT_RECOGNIZE_PER_DAY", "100")
    monkeypatch_session.setenv("UPLOAD_MAX_BYTES", str(1024 * 1024))
    get_settings.cache_clear()


@pytest.fixture(scope="session")
def monkeypatch_session() -> Iterator[pytest.MonkeyPatch]:
    mp = pytest.MonkeyPatch()
    yield mp
    mp.undo()


@pytest_asyncio.fixture(scope="session", autouse=True)
async def create_schema(configure_env) -> AsyncIterator[None]:
    settings = get_settings()
    engine = create_async_engine(settings.database_url)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    await engine.dispose()
    yield


@pytest_asyncio.fixture
async def client() -> AsyncIterator[AsyncClient]:
    # Import here so env is already set.
    from brickfinder.main import create_app

    app = create_app()
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()
```

- [ ] **Step 2: Write health test**

Create `backend/tests/integration/__init__.py` (empty).

Create `backend/tests/integration/test_health.py`:

```python
import pytest


@pytest.mark.asyncio
async def test_health_ok(client):
    r = await client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}
```

- [ ] **Step 3: Write recognize route tests**

Create `backend/tests/integration/test_recognize_route.py`:

```python
import io

import pytest
import respx
from httpx import Response


def _png_bytes(size: int = 1024) -> bytes:
    # Minimal valid PNG header + zero-padded body; FastAPI only checks content-type.
    head = b"\x89PNG\r\n\x1a\n"
    return head + b"\x00" * (size - len(head))


@pytest.mark.asyncio
async def test_recognize_happy_path(client):
    payload = {
        "items": [
            {"id": "3001", "name": "Brick 2x4", "color": "Red", "score": 0.92},
            {"id": "3001", "name": "Brick 2x4", "color": "Red", "score": 0.85},
            {"id": "3003", "name": "Brick 2x2", "color": "Yellow", "score": 0.80},
        ]
    }
    async with respx.mock(base_url="http://brickognize.test") as router:
        router.post("/predict/parts/").mock(return_value=Response(200, json=payload))
        files = {"image": ("a.png", io.BytesIO(_png_bytes()), "image/png")}
        r = await client.post("/v1/recognize", files=files)

    assert r.status_code == 200, r.text
    body = r.json()
    assert body["cache_hit"] is False
    parts = {(p["part_num"], p["color_id"]): p for p in body["parts"]}
    # Red Brick 2x4 should be quantity=2
    red = next(p for p in body["parts"] if p["part_num"] == "3001")
    assert red["quantity"] == 2


@pytest.mark.asyncio
async def test_recognize_rejects_non_image(client):
    files = {"image": ("a.txt", io.BytesIO(b"hello"), "text/plain")}
    r = await client.post("/v1/recognize", files=files)
    assert r.status_code == 400
    body = r.json()
    assert body["code"] == "INVALID_INPUT"


@pytest.mark.asyncio
async def test_recognize_rejects_oversized(client):
    big = b"\x89PNG\r\n\x1a\n" + b"\x00" * (2 * 1024 * 1024)
    files = {"image": ("big.png", io.BytesIO(big), "image/png")}
    r = await client.post("/v1/recognize", files=files)
    assert r.status_code == 400
    assert r.json()["code"] == "INVALID_INPUT"


@pytest.mark.asyncio
async def test_recognize_upstream_500_returns_502(client):
    async with respx.mock(base_url="http://brickognize.test") as router:
        router.post("/predict/parts/").mock(return_value=Response(503))
        files = {"image": ("a.png", io.BytesIO(_png_bytes()), "image/png")}
        r = await client.post("/v1/recognize", files=files)
    assert r.status_code == 502
    assert r.json()["code"] == "UPSTREAM_ERROR"


@pytest.mark.asyncio
async def test_recognize_second_call_hits_cache(client):
    payload = {"items": [{"id": "3001", "color": "Red", "score": 0.9}]}
    body = _png_bytes(2048)

    async with respx.mock(base_url="http://brickognize.test") as router:
        route = router.post("/predict/parts/").mock(return_value=Response(200, json=payload))

        files1 = {"image": ("a.png", io.BytesIO(body), "image/png")}
        r1 = await client.post("/v1/recognize", files=files1)
        assert r1.status_code == 200
        assert r1.json()["cache_hit"] is False

        files2 = {"image": ("a.png", io.BytesIO(body), "image/png")}
        r2 = await client.post("/v1/recognize", files=files2)
        assert r2.status_code == 200
        assert r2.json()["cache_hit"] is True

    assert route.call_count == 1
```

- [ ] **Step 4: Run integration tests**

Requires Docker.

```bash
pytest tests/integration -v
```

Expected: 5 passed.

If testcontainers can't start Docker in your environment, mark integration tests with `@pytest.mark.skipif` based on `DOCKER_AVAILABLE` env var — but commit the tests in their runnable form.

- [ ] **Step 5: Commit**

```bash
git add backend/tests/conftest.py backend/tests/integration/
git commit -m "test(backend): integration tests for /health and /v1/recognize"
```

---
### Task 14: Dockerfile + docker-compose for production deploy

**Files:**
- Create: `backend/Dockerfile`
- Create: `backend/docker-compose.prod.yml`
- Create: `backend/docker-compose.dev.yml`
- Create: `backend/.dockerignore`

**Interfaces:**
- Consumes: pyproject.toml, source tree
- Produces:
  - `Dockerfile` builds a slim production image installing only runtime deps. Image is published to GHCR by CI (Task 15).
  - `docker-compose.dev.yml` — used locally by developers if they want to spin up Postgres + Redis (no `backend` service; developers run uvicorn locally with `--reload`).
  - `docker-compose.prod.yml` — used on the remote server. Pulls `ghcr.io/<owner>/brickfinder-backend:<tag>` and starts it alongside Postgres + Redis. Reads `.env` from the server's working directory.

- [ ] **Step 1: Create Dockerfile**

Create `backend/Dockerfile`:

```dockerfile
# syntax=docker/dockerfile:1.7
FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Install runtime deps only (no [dev] extras).
COPY pyproject.toml ./
RUN pip install --upgrade pip && \
    pip install --no-cache-dir "fastapi>=0.110" "uvicorn[standard]>=0.27" \
    "pydantic>=2.6" "pydantic-settings>=2.2" "httpx>=0.27" "redis>=5.0" \
    "sqlalchemy[asyncio]>=2.0" "asyncpg>=0.29" "alembic>=1.13" \
    "python-multipart>=0.0.9" "structlog>=24.1" "Pillow>=10.2"

COPY src/ ./src/
COPY alembic.ini ./
COPY alembic/ ./alembic/

ENV PYTHONPATH=/app/src

EXPOSE 8000

# Migrate then serve. alembic.ini reads DATABASE_URL via brickfinder.config.
CMD ["sh", "-c", "alembic upgrade head && uvicorn brickfinder.main:app --host 0.0.0.0 --port 8000"]
```

- [ ] **Step 2: Create .dockerignore**

Create `backend/.dockerignore`:

```
.venv/
__pycache__/
*.pyc
.git/
.pytest_cache/
.ruff_cache/
.mypy_cache/
tests/
.env
docker-compose*.yml
README.md
```

- [ ] **Step 3: Create docker-compose.dev.yml**

Create `backend/docker-compose.dev.yml`:

```yaml
# Local development helper. Brings up Postgres + Redis only.
# Developers run uvicorn natively for fast reload.
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: brickfinder
      POSTGRES_PASSWORD: brickfinder
      POSTGRES_DB: brickfinder
    ports:
      - "5432:5432"
    volumes:
      - pgdata-dev:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "brickfinder"]
      interval: 5s
      timeout: 3s
      retries: 10

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 10

volumes:
  pgdata-dev:
```

- [ ] **Step 4: Create docker-compose.prod.yml**

Create `backend/docker-compose.prod.yml`:

```yaml
# Production compose. Lives on the remote server at /opt/brickfinder/.
# Image tag is rewritten by CI/CD; ${IMAGE_TAG} default is "latest".
services:
  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "${POSTGRES_USER}"]
      interval: 5s
      timeout: 3s
      retries: 10

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    volumes:
      - redisdata:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 10

  backend:
    image: ghcr.io/${GHCR_OWNER}/brickfinder-backend:${IMAGE_TAG:-latest}
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      APP_ENV: prod
      LOG_LEVEL: INFO
      DATABASE_URL: postgresql+asyncpg://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
      REDIS_URL: redis://redis:6379/0
      BRICKOGNIZE_BASE_URL: https://api.brickognize.com
      BRICKOGNIZE_TIMEOUT_SECONDS: "30"
      RATE_LIMIT_RECOGNIZE_PER_DAY: "100"
      CIRCUIT_BREAKER_THRESHOLD: "10"
      CIRCUIT_BREAKER_COOLDOWN_SECONDS: "30"
      UPLOAD_MAX_BYTES: "8388608"
    ports:
      - "8000:8000"

volumes:
  pgdata:
  redisdata:
```

- [ ] **Step 5: Local sanity build**

```bash
docker build -t brickfinder-backend:local backend/
docker run --rm -e DATABASE_URL=postgresql+asyncpg://x -e REDIS_URL=redis://x \
  brickfinder-backend:local python -c "from brickfinder.main import app; print('ok')"
```

Expected: `ok` printed. (Don't try to start the server here — Postgres isn't reachable.)

- [ ] **Step 6: Commit**

```bash
git add backend/Dockerfile backend/docker-compose.dev.yml backend/docker-compose.prod.yml backend/.dockerignore
git commit -m "feat(backend): Dockerfile and dev/prod compose files"
```

---

### Task 15: GitHub Actions — lint, test, build, push to GHCR

**Files:**
- Create: `.github/workflows/backend-ci.yml`
- Create: `.github/workflows/backend-image.yml`

**Interfaces:**
- Consumes: `backend/` source tree, `backend/Dockerfile`
- Produces:
  - `backend-ci.yml` runs on every PR + push touching `backend/`: `ruff` + `mypy` + `pytest tests/unit`. Integration tests are skipped in CI (testcontainers requires Docker-in-Docker, slow); they remain runnable locally.
  - `backend-image.yml` runs on push to `main` touching `backend/`: builds the image, tags it `latest` + `sha-<short>`, pushes to GHCR. Authenticates with the workflow's `GITHUB_TOKEN`.

- [ ] **Step 1: Create CI workflow (lint + unit tests)**

Create `.github/workflows/backend-ci.yml`:

```yaml
name: backend-ci

on:
  push:
    paths: ["backend/**", ".github/workflows/backend-ci.yml"]
  pull_request:
    paths: ["backend/**", ".github/workflows/backend-ci.yml"]

jobs:
  lint-and-unit-test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: backend
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
          cache: pip
          cache-dependency-path: backend/pyproject.toml
      - run: pip install -e ".[dev]"
      - run: ruff check .
      - run: mypy src
      - run: pytest tests/unit -v --cov=brickfinder --cov-report=term-missing
```

- [ ] **Step 2: Create image build/push workflow**

Create `.github/workflows/backend-image.yml`:

```yaml
name: backend-image

on:
  push:
    branches: [main]
    paths:
      - "backend/**"
      - ".github/workflows/backend-image.yml"
  workflow_dispatch:

permissions:
  contents: read
  packages: write

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    outputs:
      image_tag: ${{ steps.meta.outputs.tags }}
    steps:
      - uses: actions/checkout@v4

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Compute lowercase owner
        id: owner
        run: echo "value=$(echo '${{ github.repository_owner }}' | tr '[:upper:]' '[:lower:]')" >> "$GITHUB_OUTPUT"

      - name: Compute tags
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ steps.owner.outputs.value }}/brickfinder-backend
          tags: |
            type=raw,value=latest
            type=sha,format=short

      - name: Set up Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: backend
          file: backend/Dockerfile
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

- [ ] **Step 3: Push and verify**

Commit the workflow files. Push to main (or open a PR to trigger backend-ci, then merge to trigger backend-image).

After the run completes, verify the image is on GHCR:

```bash
# Locally or on the server (replace <owner> with your GitHub username/org, lowercase):
docker pull ghcr.io/<owner>/brickfinder-backend:latest
docker image inspect ghcr.io/<owner>/brickfinder-backend:latest --format '{{.Id}}'
```

Expected: image pulled successfully.

If the image is private, you need a GHCR PAT (classic, `read:packages` scope) to pull. For an open-source project, mark the package public via GitHub UI → Profile → Packages.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/backend-ci.yml .github/workflows/backend-image.yml
git commit -m "ci(backend): lint+unit on PR; build+push image to GHCR on main"
```

---

### Task 16: Deploy to remote server via SSH

**Files:**
- Create: `deploy/server-bootstrap.md` (documentation only)
- Create: `deploy/.env.prod.example`
- Create: `.github/workflows/backend-deploy.yml`

**Interfaces:**
- Consumes: published image from Task 15
- Produces:
  - One-time server bootstrap doc (Docker install, GHCR login, `/opt/brickfinder/` layout).
  - Deploy workflow: triggered after `backend-image` succeeds (or manual). SSHes to server, writes new `IMAGE_TAG`, `docker compose pull`, `docker compose up -d --remove-orphans`, runs `/health` smoke test, rolls back if it fails.

- [ ] **Step 1: Document one-time server bootstrap**

Create `deploy/server-bootstrap.md`:

```markdown
# Server bootstrap (one-time, manual)

Target: Ubuntu 22.04+ LTS, 2 vCPU / 4 GB RAM minimum.

## 1. Install Docker

    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    # log out / back in so the group takes effect

## 2. Create the deploy user (optional but recommended)

    sudo adduser --disabled-password --gecos "" deploy
    sudo usermod -aG docker deploy
    sudo mkdir -p /home/deploy/.ssh
    # Paste the GitHub Actions deploy key's public half into:
    sudo nano /home/deploy/.ssh/authorized_keys
    sudo chown -R deploy:deploy /home/deploy/.ssh
    sudo chmod 700 /home/deploy/.ssh
    sudo chmod 600 /home/deploy/.ssh/authorized_keys

## 3. Working directory

    sudo mkdir -p /opt/brickfinder
    sudo chown deploy:deploy /opt/brickfinder
    su - deploy
    cd /opt/brickfinder

## 4. Drop in compose + .env

Copy `backend/docker-compose.prod.yml` (renamed `docker-compose.yml` on the server)
and `deploy/.env.prod.example` (renamed `.env`) into `/opt/brickfinder/`.

Fill in `.env`:
- `GHCR_OWNER` — your GitHub username/org (lowercase)
- `IMAGE_TAG` — `latest`
- `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` — pick strong values

## 5. GHCR login (one-time)

If the image is private:

    echo $GHCR_PAT | docker login ghcr.io -u <github-username> --password-stdin

where `GHCR_PAT` is a classic PAT with `read:packages`.

## 6. First start

    cd /opt/brickfinder
    docker compose pull
    docker compose up -d
    curl -s localhost:8000/health

Expected: `{"status":"ok"}`. Now point a reverse proxy (Caddy/Nginx) at
`localhost:8000` if you want TLS — out of scope for M1.

## 7. GitHub repo secrets

In your GitHub repo → Settings → Secrets and variables → Actions, add:

| Secret name      | Value |
|------------------|-------|
| `DEPLOY_HOST`    | server IP / hostname |
| `DEPLOY_USER`    | `deploy` |
| `DEPLOY_SSH_KEY` | private half of the SSH key whose public half is in `~deploy/.ssh/authorized_keys` |
| `DEPLOY_PORT`    | `22` (or your custom port) |
```

- [ ] **Step 2: Create .env.prod.example**

Create `deploy/.env.prod.example`:

```bash
# Copy this file to /opt/brickfinder/.env on the server and fill in the blanks.

# GHCR image coordinates
GHCR_OWNER=your-github-username-lowercase
IMAGE_TAG=latest

# Postgres credentials (used by both postgres service and backend DATABASE_URL)
POSTGRES_USER=brickfinder
POSTGRES_PASSWORD=change-me-strong-password
POSTGRES_DB=brickfinder
```

- [ ] **Step 3: Create deploy workflow**

Create `.github/workflows/backend-deploy.yml`:

```yaml
name: backend-deploy

on:
  workflow_run:
    workflows: ["backend-image"]
    types: [completed]
    branches: [main]
  workflow_dispatch:
    inputs:
      image_tag:
        description: "Image tag to deploy (default: latest)"
        required: false
        default: "latest"

jobs:
  deploy:
    # Only run when the image build succeeded (or manually).
    if: ${{ github.event_name == 'workflow_dispatch' || github.event.workflow_run.conclusion == 'success' }}
    runs-on: ubuntu-latest
    steps:
      - name: Set image tag
        id: tag
        run: |
          if [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
            echo "value=${{ github.event.inputs.image_tag }}" >> "$GITHUB_OUTPUT"
          else
            echo "value=latest" >> "$GITHUB_OUTPUT"
          fi

      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.DEPLOY_HOST }}
          username: ${{ secrets.DEPLOY_USER }}
          key: ${{ secrets.DEPLOY_SSH_KEY }}
          port: ${{ secrets.DEPLOY_PORT }}
          envs: TAG
          script: |
            set -euo pipefail
            cd /opt/brickfinder

            # Update IMAGE_TAG in .env (idempotent).
            if grep -q "^IMAGE_TAG=" .env; then
              sed -i "s|^IMAGE_TAG=.*|IMAGE_TAG=${{ steps.tag.outputs.value }}|" .env
            else
              echo "IMAGE_TAG=${{ steps.tag.outputs.value }}" >> .env
            fi

            docker compose pull backend
            docker compose up -d --remove-orphans

            # Smoke test with a short retry; roll back if it never returns 200.
            ok=0
            for i in $(seq 1 30); do
              if curl -fsS http://localhost:8000/health >/dev/null; then ok=1; break; fi
              sleep 2
            done
            if [ "$ok" -ne 1 ]; then
              echo "Health check failed; rolling back to previous container if available." >&2
              docker compose logs --tail=200 backend || true
              exit 1
            fi
            echo "Deployed: tag=${{ steps.tag.outputs.value }}"
```

- [ ] **Step 4: First deploy (manual trigger)**

1. Complete the bootstrap doc (Task 16 Step 1) on the server
2. Push Task 15's workflows so an image gets built
3. In GitHub → Actions → backend-deploy → "Run workflow" with `image_tag=latest`
4. Watch the logs; on success curl your server: `curl http://<server>:8000/health`

Expected: `{"status":"ok"}`.

- [ ] **Step 5: Commit**

```bash
git add deploy/ .github/workflows/backend-deploy.yml
git commit -m "feat(deploy): SSH deploy workflow + server bootstrap doc"
git tag m1-backend-recognize
```

---

### Task 17: README and M1 wrap-up

**Files:**
- Modify: `backend/README.md`

**Interfaces:**
- Consumes: all earlier tasks
- Produces: README that covers local dev, tests, image build, and the deploy story.

- [ ] **Step 1: Rewrite README**

Replace `backend/README.md` with:

````markdown
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
- `.github/workflows/backend-image.yml` — build & push image on merge to `main`
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
````

- [ ] **Step 2: Final local check**

```bash
cd backend
ruff check . && mypy src && pytest tests/unit -v
```

Expected: all pass.

- [ ] **Step 3: Commit and tag**

```bash
git add backend/README.md
git commit -m "docs(backend): README covering local dev, CI, and deploy"
```

---

## Acceptance Criteria for M1

- [ ] `pytest tests/unit` passes locally with ≥80% coverage on `src/brickfinder/`
- [ ] `pytest tests/integration` passes locally with Docker available
- [ ] `ruff check .` exit 0
- [ ] `mypy src` exit 0
- [ ] `docker compose -f docker-compose.dev.yml up -d` brings up Postgres+Redis; local uvicorn returns 200 on `/health`
- [ ] CI workflow `backend-ci` passes on a PR
- [ ] CI workflow `backend-image` builds and pushes `ghcr.io/<owner>/brickfinder-backend:latest` on merge to main
- [ ] CI workflow `backend-deploy` triggers after the image is built (or via manual dispatch) and brings the service up on the remote server with `/health` returning 200
- [ ] `POST /v1/recognize` with a real image (against the deployed server) returns a `RecognizeResponse` shaped per `schemas/recognize.py`
- [ ] All five error codes (`INVALID_INPUT`, `UPSTREAM_TIMEOUT`, `UPSTREAM_ERROR`, `RATE_LIMITED`, `INTERNAL`) are reachable via tests
- [ ] No user image bytes are written to disk at any point in the request lifecycle
