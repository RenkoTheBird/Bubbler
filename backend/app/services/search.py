from app.db.topics import normalize_known_topic
from app.schemas.post import Post
from app.schemas.search import SearchResponse
from app.services.feed import _topic_sets


# Keyword hits first; semantic/related fill the rest.
_KEYWORD_LIMIT = 20
_SEMANTIC_LIMIT = 15
_MIN_SEMANTIC_SIMILARITY = 0.35
_GRAPH_RELATED_LIMIT = 5
_RELATED_CAP = 20


def _to_post(row: dict) -> Post:
    return Post(
        id=str(row["id"]),
        user_id=row["user_id"],
        username=row.get("username"),
        content=row["content"],
        embedding=None,
        created_at=row["created_at"],
        topic=row.get("topic") or "",
    )


class SearchService:
    def __init__(
        self,
        search_repo,
        graph_service,
        embedding_service,
        user_repo,
    ):
        self.search_repo = search_repo
        self.graph_service = graph_service
        self.embedding_service = embedding_service
        self.user_repo = user_repo

    async def search(self, user_id: int, query: str) -> SearchResponse:
        trimmed = query.strip() if isinstance(query, str) else ""
        if not trimmed:
            return SearchResponse(query="", exact_matches=[], related=[])

        prefs = await self.user_repo.get_prefs(user_id)
        _, blacklisted = _topic_sets(prefs.topic_preferences or [])

        known_topic = normalize_known_topic(trimmed)

        keyword_rows = await self.search_repo.keyword_search(
            trimmed, limit=_KEYWORD_LIMIT
        )
        if known_topic:
            keyword_rows = self._boost_topic_matches(keyword_rows, known_topic)

        exact_ids = {row["id"] for row in keyword_rows}

        embedding = self.embedding_service.embed_text(trimmed)
        semantic_rows = await self.search_repo.semantic_search(
            embedding,
            exclude_ids=list(exact_ids) or None,
            exclude_topics=list(blacklisted) or None,
            min_similarity=_MIN_SEMANTIC_SIMILARITY,
            limit=_SEMANTIC_LIMIT,
        )

        related_rows = list(semantic_rows)
        related_ids = {row["id"] for row in related_rows} | exact_ids

        # Light graph expansion from top keyword + semantic seeds.
        seeds = (keyword_rows[:5] + semantic_rows[:5])[:8]
        if seeds:
            async with self.search_repo.pool.acquire() as conn:
                expanded_ids = await self.graph_service.expand_posts(
                    seeds, depth=0, conn=conn
                )
            novel_ids = [
                pid for pid in expanded_ids if pid not in related_ids
            ][:_GRAPH_RELATED_LIMIT]
            if novel_ids:
                graph_posts = await self.search_repo.get_posts_by_ids(novel_ids)
                for post in graph_posts:
                    topic = (post.get("topic") or "").strip().casefold()
                    if topic and topic in blacklisted:
                        continue
                    if post["id"] in related_ids:
                        continue
                    related_rows.append(post)
                    related_ids.add(post["id"])
                    if len(related_rows) >= _RELATED_CAP:
                        break

        related_rows = related_rows[:_RELATED_CAP]

        return SearchResponse(
            query=trimmed,
            exact_matches=[_to_post(row) for row in keyword_rows],
            related=[_to_post(row) for row in related_rows],
        )

    @staticmethod
    def _boost_topic_matches(rows: list[dict], topic: str) -> list[dict]:
        """Prefer primary-topic matches when the query is a known topic label."""

        def sort_key(row: dict) -> tuple:
            primary = (row.get("topic") or "").strip().casefold()
            is_primary = primary == topic
            return (0 if is_primary else 1, -float(row.get("rank") or 0))

        return sorted(rows, key=sort_key)
