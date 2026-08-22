import logging
from dotenv import load_dotenv
from os import getenv
from urllib.parse import quote_plus

logger = logging.getLogger(__name__)

load_dotenv()

env_vars = [
    "DATABASE",
    "DB_USER",
    "DATABASE_PASSWORD",
    "HOST",
    "PORT",
    "ALGORITHM",
    "TIMEOFFSET",
    "SECRETKEY",
]

# verify the presence of all required env vars
missing = [var for var in env_vars if getenv(var) is None]

if missing:
    raise SystemExit(f"Error: Missing enviroment variable/s: {missing}")


def _int_env(name: str, default: int) -> int:
    raw = getenv(name)
    if raw is None or raw.strip() == "":
        return default
    try:
        value = int(raw)
    except ValueError as exc:
        raise SystemExit(f"Error: {name} must be an integer, got {raw!r}") from exc
    if value < 0:
        raise SystemExit(f"Error: {name} must be >= 0, got {value}")
    return value


class RetentionConfig:
    """Beta retention windows (days). Override via env; consumed by the retention job."""

    def __init__(self):
        # Rolling purge: explore/skip interactions only (likes kept for heart state).
        self.interactions_retention_days = _int_env("INTERACTIONS_RETENTION_DAYS", 270)
        self.interactions_purge_types = ("explore", "skip")

        # Anonymize attributed training rows, then delete anonymized rows later.
        self.training_events_anonymize_after_days = _int_env(
            "TRAINING_EVENTS_ANONYMIZE_AFTER_DAYS", 180
        )
        self.training_events_delete_after_days = _int_env(
            "TRAINING_EVENTS_DELETE_AFTER_DAYS", 365
        )

        # Operational counter tables (UTC calendar day keys).
        self.limit_table_retention_days = _int_env("LIMIT_TABLE_RETENTION_DAYS", 90)

        # Closed moderation tickets without legal hold (open/in_review never auto-purged).
        self.closed_report_retention_days = _int_env("CLOSED_REPORT_RETENTION_DAYS", 730)

        # Ops targets documented for runbooks; not enforced in application code.
        self.log_retention_days = _int_env("LOG_RETENTION_DAYS", 90)
        self.backup_retention_days = _int_env("BACKUP_RETENTION_DAYS", 30)


class EnvVars:

    def __init__(self):
        self.database = getenv("DATABASE")
        self.db_user = getenv("DB_USER")
        self.db_pass = getenv("DATABASE_PASSWORD")
        self.host = getenv("HOST")
        self.port = getenv("PORT")
        self.algorithm = getenv("ALGORITHM")
        self.timeoffset = int(getenv("TIMEOFFSET"))
        self.secret_key = getenv("SECRETKEY")
        self.retention = RetentionConfig()

        # helps format parse it properly
        self.db_url = f"postgresql://{self.db_user}:{quote_plus(self.db_pass)}@{self.host}:{self.port}/{self.database}"
        logger.info("Environment variables loaded successfully")


my_env_vars = EnvVars()
