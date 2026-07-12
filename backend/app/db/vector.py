'''
Since asynpg does not support vector types,
This function converts a list of floats to a string 
that can be used in a SQL query.

Used on embeddings.
'''

from typing import Any


def to_pgvector(values: list[float]) -> str:
    return "[" + ",".join(str(v) for v in values) + "]"


def from_pgvector(value: Any) -> list[float] | None:
    if value is None:
        return None
    if isinstance(value, (list, tuple)):
        return [float(v) for v in value]
    if isinstance(value, memoryview):
        value = value.tobytes().decode()
    if isinstance(value, bytes):
        value = value.decode()
    if isinstance(value, str):
        s = value.strip()
        if s.startswith("[") and s.endswith("]"):
            s = s[1:-1]
        if not s:
            return []
        return [float(x) for x in s.split(",")]
    return [float(v) for v in value]
