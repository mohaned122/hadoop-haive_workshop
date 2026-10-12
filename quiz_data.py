"""Reading and validating questions from an external quiz file.

Canonical file format (see quiz_questions.txt):

    Q. Question text here?

    A. First choice
    B. Second choice
    C. Third choice
    D. Fourth choice (*)

Rules understood by this module:
  - One block per question, blocks separated by blank lines.
  - Lines starting with "#" are ignored.
  - A block starts with a question line beginning with "Q." (or "Q:").
  - Exactly four choices must follow, beginning with "A.", "B.", "C.", "D."
    (lowercase and the ". " separator are tolerated; a trailing ")" is too).
  - The correct choice is marked with "(*)" at the very end of its line.
  - Exactly one correct choice per question.

Questions are never hardcoded here: the module only knows the file format.

The loader deduplicates questions (by normalised question text), skips malformed
blocks with a warning, and reports every problem so the file stays easy to fix.
"""

from __future__ import annotations

import os
import re
from dataclasses import dataclass
from typing import Dict, List, Tuple

_QUESTION_RE = re.compile(r"^\s*Q\s*[.:)\-]\s*(.*)$", re.IGNORECASE)
_CHOICE_RE = re.compile(r"^([A-Da-d])\s*[.:)\-]\s*(.*)$")
_CORRECT_MARKER_RE = re.compile(r"\(\*\)\s*$")


@dataclass
class Choice:
    """A single answer option for a question."""

    text: str
    correct: bool

    def __str__(self) -> str:
        return self.text


@dataclass
class Question:
    """A parsed question with its four choices."""

    text: str
    choices: List[Choice]

    @property
    def correct_index(self) -> int:
        for index, choice in enumerate(self.choices):
            if choice.correct:
                return index
        return -1

    @property
    def correct_text(self) -> str:
        index = self.correct_index
        return self.choices[index].text if index >= 0 else ""


def _strip_markdown(text: str) -> str:
    """Remove common light-markdown noise (**bold**, backticks) from a line."""
    return text.strip().replace("**", "")


def _normalise(text: str) -> str:
    """Case/format-insensitive key used to detect duplicate questions."""
    compact = re.sub(r"\W+", " ", text.lower())
    return re.sub(r"\s+", " ", compact).strip()


def _parse_block(lines: List[str]) -> Tuple[Question, List[str]]:
    """Parse a single block (list of trimmed, non-comment lines).

    Returns (Question, warnings). Raises ValueError when the block is not
    structurally a question at all.
    """
    warnings: List[str] = []

    question_text = ""
    choices: List[Choice] = []

    for line in lines:
        if question_text == "":
            match = _QUESTION_RE.match(line)
            if not match:
                raise ValueError(f"block does not start with 'Q.': {line!r}")
            question_text = _strip_markdown(match.group(1)).strip()
            continue

        match = _CHOICE_RE.match(line)
        if not match:
            warnings.append(f"ignored unrecognised line in block: {line!r}")
            continue

        label = match.group(1).upper()
        raw = match.group(2)

        # Choice lines with a "*" prefix (defensive; also tolerates the "(*) "
        # style where the marker is not at the very end).
        correct = bool(_CORRECT_MARKER_RE.search(raw))
        text = _CORRECT_MARKER_RE.sub("", raw).strip()
        text = _strip_markdown(text)

        choices.append(
            Choice(
                text=text.strip(),
                correct=correct or raw.startswith("* ") or raw.startswith("*"),
            )
        )
        if label not in ("A", "B", "C", "D"):
            warnings.append(f"ignored choice line with unknown label: {line!r}")

    if not question_text:
        raise ValueError("block has no question text")

    if len(choices) != 4:
        warnings.append(
            f"skipping question: expected exactly 4 choices (A-D), got {len(choices)}"
        )
        raise ValueError(f"expected 4 choices, got {len(choices)}")

    correct_count = sum(1 for c in choices if c.correct)
    if correct_count != 1:
        warnings.append(
            f"skipping question: expected exactly one (*) marker, got {correct_count}"
        )
        raise ValueError(f"expected 1 correct choice, got {correct_count}")

    return Question(text=question_text, choices=choices), warnings


def load_questions(path: str) -> Tuple[List[Question], List[str]]:
    """Load questions from *path*.

    Returns (questions, warnings). The returned list is deduplicated and free
    of malformed blocks. Raises FileNotFoundError if the file is missing.
    """
    if not os.path.exists(path):
        raise FileNotFoundError(f"questions file not found: {path}")

    content = _read_text(path)

    warnings: List[str] = []
    seen_keys: Dict[str, bool] = {}

    # Group lines into blocks. A new block starts at every "Q." line, so blank
    # lines anywhere inside a block (e.g. between the question and its choices)
    # are fine. Comment lines are ignored entirely.
    blocks: List[List[str]] = []
    current: List[str] = []
    for raw in content.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if _QUESTION_RE.match(line):
            if current:
                blocks.append(current)
            current = [line]
        elif current:
            current.append(line)
        else:
            warnings.append(f"ignored line before any question: {line!r}")
    if current:
        blocks.append(current)

    questions: List[Question] = []
    for block in blocks:
        try:
            question, block_warnings = _parse_block(block)
        except ValueError as error:
            short = " ".join(block[:1])[:80] if block else "<empty block>"
            warnings.append(f"malformed block ({error}): {short!r}")
            continue
        warnings.extend(f"  {w}" for w in block_warnings)

        # Deduplicate on normalised question text (case/punctuation-insensitive).
        key = _normalise(question.text)
        if key in seen_keys:
            warnings.append(f"duplicate question skipped: {question.text[:60]!r}")
            continue
        seen_keys[key] = True
        questions.append(question)

    return questions, warnings


def _read_text(path: str) -> str:
    """Read a text file, tolerant of BOM and of non-UTF-8 legacy encodings."""
    for encoding in ("utf-8-sig", "utf-8", "latin-1"):
        try:
            with open(path, "r", encoding=encoding) as handle:
                return handle.read()
        except UnicodeDecodeError:
            continue
    # Encoding sniffing failed: let a final plain read decide the exception.
    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        return handle.read()