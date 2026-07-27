"""Named-entity recognition for Exactitude claim detection.

Replaces Roundabout's in-browser ``bert-base-NER`` (Transformers.js) with
spaCy NER on the backend. Entities feed specificity, location, time/date,
and source-clarity dimensions.
"""

from __future__ import annotations

import threading
from typing import Any

# Same lightweight English model as spacy_signals (includes NER pipe).
_SPACY_MODEL_NAME = "en_core_web_sm"

_nlp = None
_lock = threading.Lock()


def _get_nlp():
    """Load spaCy once per process (thread-safe)."""
    global _nlp
    if _nlp is None:
        with _lock:
            if _nlp is None:
                import spacy

                _nlp = spacy.load(_SPACY_MODEL_NAME)
    return _nlp


def preload_model() -> None:
    """Eagerly load spaCy so the first scoring request is not a cold start."""
    _get_nlp()


def extract_entities(text: str) -> list[dict[str, Any]]:
    """Run NER on a single clause/sentence.

    Each entity dict is intended to look like::

        {"text": str, "label": str, "start": int, "end": int}

    Labels of interest for Exactitude: DATE, TIME, GPE, LOC, ORG, PERSON,
    MONEY, PERCENT, QUANTITY, CARDINAL.

    Args:
        text: One clause from ``sentence_split.get_clauses``.

    Returns:
        List of entity dicts. Skeleton returns [] until wiring is finished.
    """
    if not text or not isinstance(text, str):
        return []

    nlp = _get_nlp()
    doc = nlp(text.strip())

    # TODO: map doc.ents → [{text, label, start, end}, ...].
    _ = doc
    return []


def entities_by_label(text: str, labels: set[str] | frozenset[str]) -> list[dict[str, Any]]:
    """Return entities whose label is in ``labels``.

    Skeleton filters ``extract_entities``; useful for dimension helpers
    (e.g. location → GPE/LOC, source → ORG).
    """
    if not labels:
        return []
    return [ent for ent in extract_entities(text) if ent.get("label") in labels]
