# syntax=docker/dockerfile:1.7
FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Install runtime deps from pyproject.toml (single source of truth).
COPY pyproject.toml ./
COPY src/ ./src/
RUN pip install --upgrade pip && \
    pip install --no-cache-dir .

COPY alembic.ini ./
COPY alembic/ ./alembic/

EXPOSE 8000

# Migrate then serve. alembic.ini reads DATABASE_URL via brickfinder.config.
CMD ["sh", "-c", "alembic upgrade head && uvicorn brickfinder.main:app --host 0.0.0.0 --port 8000"]
