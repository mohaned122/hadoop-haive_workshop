"""Console quiz application for the Hadoop/Hive workshop.

Reads questions from an external text file (never hardcoded), asks them one at
a time in random order, measures response time, and scores answers by
correctness plus a configurable speed bonus.

Usage:
    python quiz_app.py
    python quiz_app.py --questions quiz_questions.txt
    python quiz_app.py --time-limit 20 --base-points 10 --bonus 5
    python quiz_app.py --config quiz_config.json
    python quiz_app.py --list          # validate/print the file, do not play

See QUIZ_README.md for the full reference.
"""

from __future__ import annotations

import argparse
import random
import sys
import threading
import time
from typing import List, Optional, Sequence, Tuple

from quiz_data import Question, load_questions
from quiz_scoring import (
    QuizConfig,
    build_config,
    max_achievable_points,
    performance_rating,
    score_question,
)

DEFAULT_QUESTIONS_FILE = "quiz_questions.txt"
ANSWER_PROMPT = "Your answer (A/B/C/D or 1-4): "
_LETTERS = ("A", "B", "C", "D")


# --------------------------------------------------------------------------- #
# Command-line interface
# --------------------------------------------------------------------------- #
def parse_args(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Interactive Hadoop/Hive workshop quiz.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "-q",
        "--questions",
        default=DEFAULT_QUESTIONS_FILE,
        help="path to the questions text file",
    )
    parser.add_argument(
        "-c", "--config", default=None, help="path to a JSON config file"
    )
    parser.add_argument(
        "--time-limit",
        type=float,
        default=None,
        help="seconds allowed per question before timeout",
    )
    parser.add_argument(
        "--base-points",
        type=float,
        default=None,
        help="points for a correct answer (before speed bonus)",
    )
    parser.add_argument(
        "--bonus",
        dest="max_speed_bonus",
        type=float,
        default=None,
        help="maximum extra points for a very fast correct answer",
    )
    parser.add_argument(
        "--seed", type=int, default=None, help="RNG seed for a reproducible order"
    )
    parser.add_argument(
        "--no-shuffle",
        action="store_true",
        help="keep the file order instead of shuffling questions",
    )
    parser.add_argument(
        "--list",
        dest="list_only",
        action="store_true",
        help="print the parsed questions and exit (file validation)",
    )
    return parser.parse_args(argv)


def _config_from_args(args: argparse.Namespace) -> QuizConfig:
    cli_overrides = {
        "time_limit": args.time_limit,
        "base_points": args.base_points,
        "max_speed_bonus": args.max_speed_bonus,
        "seed": args.seed,
        # --no-shuffle forces shuffle off; otherwise leave None (config decides).
        "shuffle": False if args.no_shuffle else None,
    }
    return build_config(args.config, cli_overrides=cli_overrides)


# --------------------------------------------------------------------------- #
# Presenting questions
# --------------------------------------------------------------------------- #
def print_question(question: Question, index: int, total: int, show_marker: bool) -> None:
    print(f"\nQuestion {index}/{total}")
    print("-" * 60)
    print(f"Q. {question.text}")
    for letter, choice in zip(_LETTERS, question.choices):
        marker = " (*)" if (show_marker and choice.correct) else ""
        print(f"  {letter}. {choice.text}{marker}")
    print("-" * 60)


def parse_answer(raw: Optional[str]) -> Optional[int]:
    """Translate user input into a 0-based choice index, or None if invalid."""
    if raw is None:
        return None
    value = raw.strip().upper()
    if value in _LETTERS:
        return _LETTERS.index(value)
    if value in ("1", "2", "3", "4"):
        return int(value) - 1
    return None


def ask_with_timeout(prompt: str, timeout: float) -> Tuple[Optional[str], float, bool, threading.Thread]:
    """Read one line of input, giving up after *timeout* seconds.

    Returns (value, seconds_used, timed_out, reader_thread). The caller may
    ``join()`` the returned thread after reporting a timeout to consume the
    still-pending Enter key cleanly before the next question.
    """
    result: dict = {}
    finished = threading.Event()

    def _reader() -> None:
        try:
            result["value"] = input(prompt)
        except (EOFError, KeyboardInterrupt):
            result["value"] = ""
        finally:
            finished.set()

    thread = threading.Thread(target=_reader, daemon=True)
    start = time.perf_counter()
    thread.start()
    completed = finished.wait(timeout)
    seconds = time.perf_counter() - start

    if completed:
        return result.get("value"), seconds, False, thread
    return None, seconds, True, thread


def run_quiz(questions: List[Question], config: QuizConfig) -> dict:
    """Ask every question and return aggregate statistics."""
    total = len(questions)
    correct_count = 0
    timed_out_count = 0
    total_score = 0.0
    response_times: List[float] = []
    records: List[dict] = []

    quiz_start = time.perf_counter()

    for index, question in enumerate(questions, start=1):
        print_question(question, index, total, show_marker=False)

        question_start = time.perf_counter()
        answer_index: Optional[int] = None
        timed_out = False

        while True:
            remaining = config.time_limit - (time.perf_counter() - question_start)
            if remaining <= 0:
                timed_out = True
                break

            raw, _elapsed, hit_timeout, thread = ask_with_timeout(
                ANSWER_PROMPT, remaining
            )
            if hit_timeout:
                timed_out = True
                # The reader thread is likely still blocked on input(); wait for
                # the user's Enter so it does not swallow the next answer.
                print("Time's up! This question counts as incorrect.")
                print("Press Enter to continue...")
                thread.join()
                break

            parsed = parse_answer(raw)
            if parsed is None:
                print("Invalid input. Enter A, B, C or D (1-4 also works).")
                continue
            answer_index = parsed
            break

        elapsed = min(time.perf_counter() - question_start, config.time_limit)
        response_times.append(elapsed)

        was_correct = False
        if not timed_out and answer_index is not None:
            was_correct = question.choices[answer_index].correct

        points = score_question(was_correct, elapsed, config)
        total_score += points
        if was_correct:
            correct_count += 1
        if timed_out:
            timed_out_count += 1

        records.append(
            {
                "question": question,
                "your_index": answer_index,
                "correct": was_correct,
                "timed_out": timed_out,
                "seconds": elapsed,
                "points": points,
            }
        )

        if was_correct:
            verdict = f"CORRECT  (+{points:g} pts)"
        elif timed_out:
            verdict = "TIMEOUT  (0 pts)"
        else:
            verdict = "WRONG    (0 pts)"
        print(f"  -> {verdict}")

    total_duration = time.perf_counter() - quiz_start
    return {
        "total": total,
        "correct_count": correct_count,
        "incorrect_count": total - correct_count,
        "timed_out_count": timed_out_count,
        "total_score": round(total_score, 2),
        "response_times": response_times,
        "records": records,
        "total_duration": total_duration,
    }


# --------------------------------------------------------------------------- #
# Results
# --------------------------------------------------------------------------- #
def show_results(stats: dict, config: QuizConfig) -> None:
    total = stats["total"]
    correct = stats["correct_count"]
    total_score = stats["total_score"]
    maximum = max_achievable_points(total, config)
    score_percentage = (total_score / maximum * 100.0) if maximum else 0.0
    accuracy = (correct / total * 100.0) if total else 0.0
    avg_time = (
        sum(stats["response_times"]) / len(stats["response_times"])
        if stats["response_times"]
        else 0.0
    )
    rating = performance_rating(score_percentage, config)

    print("\n" + "=" * 60)
    print("RESULTS")
    print("=" * 60)
    print(f"Total score        : {total_score:g} / {maximum:g}  ({score_percentage:.1f}%)")
    print(f"Correct answers    : {correct}")
    print(f"Incorrect answers  : {stats['incorrect_count']}")
    print(f"Timeouts           : {stats['timed_out_count']}")
    print(f"Accuracy           : {accuracy:.1f}%")
    print(f"Total duration     : {stats['total_duration']:.1f} s")
    print(f"Average response   : {avg_time:.2f} s/question")
    print(f"Time limit         : {config.time_limit:g} s/question")
    print(f"Performance rating : {rating}")
    print("=" * 60)

    print("\nAnswer recap:")
    for number, record in enumerate(stats["records"], start=1):
        question: Question = record["question"]
        if record["timed_out"]:
            given = "-- timeout --"
        elif record["your_index"] is None:
            given = "--"
        else:
            given = f"{_LETTERS[record['your_index']]}. {question.choices[record['your_index']].text}"

        status = "OK " if record["correct"] else "X  "
        print(f"  [{status}] {number:>2}. {question.text[:52]}")
        print(f"         your answer : {given}")
        print(
            f"         correct     : {_LETTERS[question.correct_index]}. "
            f"{question.correct_text}"
        )
        print(
            f"         time        : {record['seconds']:.2f}s "
            f"-> {record['points']:g} pts"
        )


def list_questions(questions: List[Question]) -> None:
    print(f"Parsed {len(questions)} valid question(s).")
    for index, question in enumerate(questions, start=1):
        print_question(question, index, len(questions), show_marker=True)


# --------------------------------------------------------------------------- #
# Entry point
# --------------------------------------------------------------------------- #
def main(argv: Optional[Sequence[str]] = None) -> int:
    args = parse_args(argv)

    try:
        config = _config_from_args(args)
    except (ValueError, FileNotFoundError) as error:
        print(f"Configuration error: {error}", file=sys.stderr)
        return 2

    try:
        questions, warnings = load_questions(args.questions)
    except FileNotFoundError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 2

    for warning in warnings:
        print(f"[warning] {warning}", file=sys.stderr)
    if warnings:
        print(
            f"[warning] {len(warnings)} issue(s) in {args.questions}; "
            "malformed questions were skipped.\n",
            file=sys.stderr,
        )

    if not questions:
        print(
            f"Error: no valid questions found in '{args.questions}'.",
            file=sys.stderr,
        )
        return 2

    if args.list_only:
        list_questions(questions)
        return 0

    if config.shuffle:
        rng = random.Random(config.seed) if config.seed is not None else random
        rng.shuffle(questions)

    print("=" * 60)
    print("Hadoop / Hive Workshop Quiz")
    print("=" * 60)
    print(f"Questions        : {len(questions)}")
    print(f"Time limit       : {config.time_limit:g} s/question")
    print(f"Points/correct   : {config.base_points:g} (+ up to {config.max_speed_bonus:g} speed bonus)")
    print(f"Max score        : {max_achievable_points(len(questions), config):g}")
    print("=" * 60)
    print("Answer with A, B, C or D (or 1-4). Press Ctrl+C to quit.\n")

    try:
        stats = run_quiz(questions, config)
    except KeyboardInterrupt:
        print("\n\nQuiz interrupted. No final score.")
        return 1

    show_results(stats, config)
    return 0


if __name__ == "__main__":
    sys.exit(main())