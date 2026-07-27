"""Sentence splitting for Exactitude claim detection.

Mirrors the frontend ``getClauses`` helper: split post text into sentences
(via locale-aware segmentation in JS / an English approximation here), then
keep only those with at least three words so trivial fragments are skipped
before on-demand Exactitude scoring.
"""

from __future__ import annotations

import re

# Approximate Intl.Segmenter("en", { granularity: "sentence" }).
# Break after terminal punctuation (. ! ? …), optional closing quotes/brackets,
# then whitespace. Hard newlines also start a new sentence (common in posts).
_SENTENCE_BOUNDARY = re.compile(
    r"(?<=[.!?…])[\"'”’)\]]*(?=\s)|(?<=\n)",
)

_MIN_WORDS = 3


def get_clauses(text: object) -> list[str]:
    """Split post text into sentences for claim detection.

    Input: raw string (caption, tweet body, or combined Reddit title + body).
    Returns only sentences with at least 3 words (to avoid trivial fragments).

    Args:
        text: Raw post text (or combined text, e.g. Reddit title + "\\n\\n" + body).

    Returns:
        Trimmed sentences with 3+ words each.
    """
    if text is None or not isinstance(text, str):
        return []

    trimmed = text.strip()
    if not trimmed:
        return []

    sentences: list[str] = []
    for part in _SENTENCE_BOUNDARY.split(trimmed):
        sentence = part.strip()
        if not sentence:
            continue
        if len(sentence.split()) >= _MIN_WORDS:
            sentences.append(sentence)
    return sentences
