"""Topic constants — extend KNOWN_TOPICS when the curated list is defined."""

DEFAULT_TOPIC = "general"

# NOTE: In the future, topics will be determined
# by AI/ML models. This will also allow for more
# diverse and nuanced topics to be identified.
# However since this is an MVP, we use a static
# list of topics for now.
KNOWN_TOPICS: frozenset[str] = frozenset({
    DEFAULT_TOPIC,
    "politics",
    "technology",
    "science",
    "entertainment",
    "sports",
    "business",
    "health",
    "education",
    "environment",
})
