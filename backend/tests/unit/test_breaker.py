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
    cb.record_failure()
    cb.record_failure()
    assert not cb.allow()
    clock.now = 11
    assert cb.allow()


def test_success_resets_counter():
    clock = FakeClock()
    cb = CircuitBreaker(threshold=3, cooldown_seconds=10, clock=clock)
    cb.record_failure()
    cb.record_failure()
    cb.record_success()
    cb.record_failure()
    cb.record_failure()
    assert cb.allow()


def test_circuit_open_error_raised_via_helper():
    clock = FakeClock()
    cb = CircuitBreaker(threshold=1, cooldown_seconds=10, clock=clock)
    cb.record_failure()
    with pytest.raises(CircuitOpenError):
        cb.check_or_raise()
