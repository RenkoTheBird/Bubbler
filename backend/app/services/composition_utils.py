"""Shared quota allocation for composition-weighted candidate selection."""


def weighted_quotas(weights: dict[str, float], slots: int) -> dict[str, int]:
    if slots <= 0:
        return {key: 0 for key in weights}
    positive = {key: max(float(value), 0.0) for key, value in weights.items()}
    total = sum(positive.values())
    if total <= 0:
        positive = {key: 1.0 for key in weights}
        total = float(len(positive))

    raw = {key: slots * value / total for key, value in positive.items()}
    quotas = {key: int(value) for key, value in raw.items()}
    unassigned = slots - sum(quotas.values())
    order = sorted(
        raw,
        key=lambda key: (raw[key] - quotas[key], positive[key]),
        reverse=True,
    )
    for key in order[:unassigned]:
        quotas[key] += 1
    return quotas
