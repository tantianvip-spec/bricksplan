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
