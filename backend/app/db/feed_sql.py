"""Shared SQL for feed queries — primary topic via post_topics (matches interaction_repo)."""

POST_PRIMARY_TOPIC_LATERAL = """
LEFT JOIN LATERAL (
    SELECT topic_name AS topic
    FROM post_topics
    WHERE post_id = p.id
    ORDER BY weight DESC
    LIMIT 1
) pt ON true
"""

POSTS_BASE_FROM = f"""
FROM posts p
{POST_PRIMARY_TOPIC_LATERAL}
"""

POSTS_WITH_TOPIC_COLUMNS = "p.id, p.content, pt.topic, p.created_at, p.user_id"

POSTS_WITH_TOPIC_VIEW = "posts_with_topic"
