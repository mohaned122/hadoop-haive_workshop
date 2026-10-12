"""Configurable scoring rules, time limits and performance rating.

All rules live in :class:`QuizConfig`. Values can be supplied (in increasing
priority) by: built-in defaults, a JSON config file, environment variables, and
command-line options. Nothing here is tied to specific questions.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from typing import Any, Dict, Optional

DEFAULT_RATING_THRESHOLDS: Dict[str, float] = {
    "Excellent": 90.0,
    "Good": 75.0,
    "Fair": 60.0,
    "Needs practice": 0.0,
}

_ENV_MAP = {
    "QUIZ_TIME_LIMIT": "time_limit",
    "QUIZ_BASE_POINTS": "base_points",
    "QUIZ_SPEED_BONUS": "max_speed_bonus",
    "QUIZ_SHUFFLE": "shuffle",
    "QUIZ_SEED": "seed",
}


@dataclass
class QuizConfig:
    """Scoring configuration. Every field is overridable from outside."""

    # Seconds allowed per question before it counts as an (incorrect) timeout.
    time_limit: float = 15.0
    # Points awarded for a correct answer (before the speed bonus).
    base_points: float = 10.0
    # Maximum extra points for answering instantly (scales down to 0 at the limit).
    max_speed_bonus: float = 5.0
    # Randomise the question order.
    shuffle: bool = True
    # Optional RNG seed for reproducible runs (None = truly random).
    seed: Optional[int] = None
    # Performance-rating label -> minimum score percentage.
    rating_thresholds: Dict[str, float] = field(
        default_factory=lambda: dict(DEFAULT_RATING_THRESHOLDS)
    )

    @property
    def max_points_per_question(self) -> float:
        return self.base_points + self.max_speed_bonus


def score_question(correct: bool, seconds: float, config: QuizConfig) -> float:
    """Return the points earned for one answer.

    Incorrect answers (including timeouts) always score zero. A correct answer
    earns ``base_points`` plus a speed bonus that decreases linearly with the
    time taken, reaching zero at ``time_limit``.
    """
    if not correct:
        return 0.0

    if config.time_limit <= 0:
        fraction_left = 0.0
    else:
        fraction_left = 1.0 - (seconds / config.time_limit)
    fraction_left = max(0.0, min(1.0, fraction_left))

    return round(config.base_points + config.max_speed_bonus * fraction_left, 2)


def performance_rating(score_percentage: float, config: QuizConfig) -> str:
    """Map a score percentage to a rating label using configured thresholds."""
    ordered = sorted(
        config.rating_thresholds.items(), key=lambda item: item[1], reverse=True
    )
    for label, minimum in ordered:
        if score_percentage >= minimum:
            return label
    return ordered[-1][0] if ordered else "Unrated"


def max_achievable_points(question_count: int, config: QuizConfig) -> float:
    return round(question_count * config.max_points_per_question, 2)


def build_config(
    config_path: Optional[str] = None,
    cli_overrides: Optional[Dict[str, Any]] = None,
    use_env: bool = True,
) -> QuizConfig:
    """Assemble a :class:`QuizConfig` from all supported sources.

    Priority (low to high): defaults < JSON file < environment < CLI options.
    """
    config = QuizConfig()

    if config_path:
        _apply_file(config, config_path)

    if use_env:
        _apply_env(config)

    if cli_overrides:
        _apply_mapping(config, {k: v for k, v in cli_overrides.items() if v is not None})

    return config


def _apply_file(config: QuizConfig, path: str) -> None:
    if not os.path.exists(path):
        raise FileNotFoundError(f"config file not found: {path}")
    try:
        with open(path, "r", encoding="utf-8-sig") as handle:
            data = json.load(handle)
    except json.JSONDecodeError as error:
        raise ValueError(f"config file is not valid JSON ({path}): {error}") from error

    if not isinstance(data, dict):
        raise ValueError(f"config file must contain a JSON object: {path}")
    _apply_mapping(config, data)


def _apply_mapping(config: QuizConfig, values: Dict[str, Any]) -> None:
    for key, value in values.items():
        if key == "rating_thresholds":
            if not isinstance(value, dict):
                raise ValueError("rating_thresholds must be an object of label->number")
            config.rating_thresholds = {
                str(label): float(minimum) for label, minimum in value.items()
            }
        elif key == "seed":
            config.seed = None if value in (None, "", "none", "None") else int(value)
        elif key == "shuffle":
            config.shuffle = _to_bool(value)
        elif key in ("time_limit", "base_points", "max_speed_bonus"):
            number = float(value)
            if number < 0:
                raise ValueError(f"{key} cannot be negative")
            setattr(config, key, number)
        # Unknown keys are ignored so the file can carry extra metadata.


def _apply_env(config: QuizConfig) -> None:
    values: Dict[str, Any] = {}
    for env_name, field_name in _ENV_MAP.items():
        if env_name in os.environ:
            values[field_name] = os.environ[env_name]
    if values:
        _apply_mapping(config, values)


def _to_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    return str(value).strip().lower() in ("1", "true", "yes", "y", "on")