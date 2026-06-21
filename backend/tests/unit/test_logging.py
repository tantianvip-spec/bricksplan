import json

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
    lines = [line for line in captured.out.strip().splitlines() if line]
    assert any("visible" in line for line in lines)
    assert not any("hidden" in line for line in lines)
