from datetime import datetime, timezone


def ensure_utc(value: datetime | None) -> datetime | None:
    """Treat naive DB timestamps as UTC and normalize aware values to UTC."""
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def utc_iso_z(value: datetime | None) -> str | None:
    """Emit UTC timestamps as RFC 3339 with millisecond precision and a Z suffix.

    Matches what iOS ``ISO8601DateFormatter`` (withInternetDateTime + fractional
    seconds) expects, unlike naive Postgres ``TIMESTAMP`` isoformat output.
    """
    dt = ensure_utc(value)
    if dt is None:
        return None
    return dt.isoformat(timespec="milliseconds").replace("+00:00", "Z")


def with_utc_created_at(post: dict) -> dict:
    """Copy a post dict, serializing created_at for JSON API responses."""
    out = dict(post)
    created_at = out.get("created_at")
    if isinstance(created_at, datetime):
        out["created_at"] = utc_iso_z(created_at)
    return out
