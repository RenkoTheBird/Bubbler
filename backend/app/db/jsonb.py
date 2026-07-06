import json


def normalize_strategy_weights(raw_value, *, defaults: dict[str, float]) -> dict[str, float]:
    normalized = dict(defaults)

    if raw_value is None:
        return normalized

    if isinstance(raw_value, str):
        try:
            raw_value = json.loads(raw_value)
        except json.JSONDecodeError:
            return normalized

    if hasattr(raw_value, "items"):
        items = raw_value.items()
    else:
        try:
            items = dict(raw_value).items()
        except (TypeError, ValueError):
            return normalized

    for key, value in items:
        try:
            normalized[str(key)] = float(value)
        except (TypeError, ValueError):
            continue

    return normalized
