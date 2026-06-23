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

    rebrickable_api_key: str = ""
    rebrickable_timeout_seconds: float = 15.0

    rate_limit_parts_search_per_day: int = 500


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()  # type: ignore[call-arg]
