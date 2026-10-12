# Hadoop / Hive Workshop Quiz — Console App

An interactive console quiz. It reads questions from an **external text file**
(never hardcoded), shows them one at a time in random order, times each answer,
and scores by correctness plus a configurable speed bonus.

---

## Requirements

- Python 3.8+ (tested on 3.14). No third-party packages.
- Run from this folder (the scripts import each other by filename).

## Files

| File                     | Purpose                                                    |
|--------------------------|------------------------------------------------------------|
| `quiz_app.py`            | Entry point: the console quiz                              |
| `quiz_data.py`           | Loads and validates questions, removes duplicates          |
| `quiz_scoring.py`        | Configurable scoring rules, time limits, rating             |
| `quiz_questions.txt`     | **The question bank** (editable — add your own questions)   |
| `quiz_config.example.json` | Optional example config file                             |

---

## How to run

```powershell
# Play with defaults (reads quiz_questions.txt)
python quiz_app.py

# Validate the question file and print it (no quiz) — use after editing it
python quiz_app.py --list

# Override scoring / time on the fly
python quiz_app.py --time-limit 20 --base-points 12 --bonus 8

# Use a JSON config file
python quiz_app.py --config quiz_config.example.json

# Reproducible question order (same seed = same order)
python quiz_app.py --seed 42

# Keep the file order (no shuffle)
python quiz_app.py --no-shuffle

# Use a different question file
python quiz_app.py --questions my_questions.txt
```

Inside the quiz, answer with `A`, `B`, `C` or `D` (or `1`–`4`). Press `Ctrl+C`
to quit at any time.

---

## Scoring rules

For every question:

- **Incorrect or timed out** → **0 points**.
- **Correct** → `base_points` **+ a speed bonus**.
  The bonus is `max_speed_bonus` when you answer instantly and shrinks linearly
  to `0` as you approach the time limit:

  ```
  bonus = max_speed_bonus * max(0, 1 - (seconds_taken / time_limit))
  points = base_points + bonus            (correct answers only)
  ```

  Example (defaults `base=10`, `bonus=5`, `limit=15s`): answering correctly in
  3 s gives `10 + 5*(1-3/15) = 14` points; at 15 s it gives `10`.

If you take longer than `time_limit`, the question is skipped, counts as
incorrect, and you must press Enter to continue.

## Configuration

Settings can come from three places. **Priority (low → high): defaults → JSON
config file → environment variables → command-line options.**

| Setting                | CLI option        | Environment variable   | JSON key            | Default |
|------------------------|-------------------|------------------------|---------------------|---------|
| Time limit (seconds)   | `--time-limit`    | `QUIZ_TIME_LIMIT`      | `time_limit`        | `15`    |
| Points per correct     | `--base-points`   | `QUIZ_BASE_POINTS`     | `base_points`       | `10`    |
| Max speed bonus        | `--bonus`         | `QUIZ_SPEED_BONUS`     | `max_speed_bonus`   | `5`     |
| Shuffle order          | `--no-shuffle`    | `QUIZ_SHUFFLE`         | `shuffle`           | `true`  |
| Reproducible seed      | `--seed`          | `QUIZ_SEED`            | `seed`              | `null`  |
| Rating thresholds      | —                 | —                      | `rating_thresholds` | see below |

Default rating thresholds (score %): `Excellent` ≥ 90, `Good` ≥ 75,
`Fair` ≥ 60, otherwise `Needs practice`. Edit them in a config file to change
the labels or cutoffs.

---

## The question file format

`quiz_questions.txt` is plain text. Each question is a block, separated by blank
lines. Lines starting with `#` are comments.

```
Q. Question text here?

A. First choice
B. Second choice
C. Third choice
D. Fourth choice (*)
```

Rules:

1. The question line starts with `Q.` (or `Q:`).
2. Exactly **four** choices follow, starting with `A.`, `B.`, `C.`, `D.`.
3. The **correct** choice ends with `(*)` — exactly one per question.

### Adding a question

Copy any block, paste it, edit the text, and put `(*)` on the correct choice.
Nothing in the Python code needs to change. Then run:

```powershell
python quiz_app.py --list
```

This validates the file, prints every question, and warns about any block that
has the wrong number of choices, is missing the `(*)` marker, or is a duplicate.
Duplicate questions (same text, ignoring case/punctuation) are dropped
automatically; malformed blocks are skipped with a warning.

---

## What the results show

After the last question you get the total score and maximum, correct/incorrect
counts and timeouts, accuracy percentage, total duration, average response time,
a performance rating, and a per-question recap (your answer, the correct answer,
time taken, and points).

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `questions file not found` | Run from this folder, or pass `--questions <path>` |
| `no valid questions found` | Run `--list`; check every block has 4 choices and one `(*)` |
| `Configuration error: ...` | Check the JSON config syntax / values |
| Accents look wrong in the console | Use Windows Terminal or run `chcp 65001` first |
