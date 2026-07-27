"""spaCy linguistic signals for Exactitude claim detection.

Replaces Roundabout's in-browser ``compromise`` feature extraction with a
server-side spaCy pipeline: dates/times, quantities, POS, pronouns, and
modality cues used by the seven Exactitude dimensions.
"""

from __future__ import annotations

import threading
from typing import Any

# Lightweight English model with tagger, parser, NER, and lemmatizer.
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


def extract_signals(text: str) -> dict[str, Any]:
    """Extract linguistic signals from a single clause/sentence.

    Intended keys (filled by later dimension wiring):
      - date_time: bool / spans for temporal expressions
      - quantification: bool / numeric & quantity spans
      - location_cues: bool (coarse; prefer ner.py for GPE/LOC)
      - first_person: bool / pronoun hits (personal-relativity penalty)
      - modality: hedging / absolute markers for falsifiability
      - source_cues: attribution / reporting verbs (coarse)

    Args:
        text: One clause from ``sentence_split.get_clauses``.

    Returns:
        Signal dict for Exactitude dimension scoring. Skeleton returns empty
        structure until dimension extractors are implemented.
    """
    if not text or not isinstance(text, str):
        return _empty_signals()

    nlp = _get_nlp()
    doc = nlp(text.strip())

    # TODO: walk doc for DATE/TIME, NUM/QUANTITY-like tokens, pronouns,
    # modality lemmas, and attribution verbs; populate the dict below.
    _ = doc  # keep parse wired for upcoming extractors
    return _empty_signals()


def _empty_signals() -> dict[str, Any]:
    return {
        "date_time": False,
        "quantification": False,
        "location_cues": False,
        "first_person": False,
        "modality": [],
        "source_cues": False,
    }
