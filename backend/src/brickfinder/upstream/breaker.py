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
