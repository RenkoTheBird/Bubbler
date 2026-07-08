"""Shared SQL for feed queries — primary topic via posts_with_topic view."""

POSTS_WITH_TOPIC_VIEW = "posts_with_topic"

POSTS_BASE_FROM = f"FROM {POSTS_WITH_TOPIC_VIEW} pwt"

POSTS_WITH_TOPIC_COLUMNS = "pwt.id, pwt.content, pwt.topic, pwt.created_at, pwt.user_id"

# TABLESAMPLE applies to posts; join the view for denormalized topic.
POSTS_TABLESAMPLE_FROM = f"""
FROM posts p TABLESAMPLE BERNOULLI ({{sample_percent}})
JOIN {POSTS_WITH_TOPIC_VIEW} pwt ON pwt.id = p.id
"""
