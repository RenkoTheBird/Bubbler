import math
from collections.abc import Iterable

from app.db.topics import KNOWN_TOPICS
from app.services.post import EmbeddingService

AI_TOPIC_MATCH_LIMIT = 3
AI_TOPIC_SIMILARITY_THRESHOLD = 0.5
AI_TOPIC_HIDDEN_WEIGHT = 0.0


class TopicDetectionService:
    def __init__(self, repo, embedding_service: EmbeddingService):
        self.repo = repo
        self.embedding_service = embedding_service
        self._known_topic_embeddings: dict[str, list[float]] | None = None

    def _get_known_topic_embeddings(self) -> dict[str, list[float]]:
        if self._known_topic_embeddings is None:
            self._known_topic_embeddings = {
                topic_name: self.embedding_service.embed_text(topic_name)
                for topic_name in sorted(KNOWN_TOPICS)
            }
        return self._known_topic_embeddings

    @staticmethod
    def _cosine_similarity(left: Iterable[float], right: Iterable[float]) -> float:
        numerator = 0.0
        left_norm = 0.0
        right_norm = 0.0

        for left_value, right_value in zip(left, right):
            numerator += left_value * right_value
            left_norm += left_value * left_value
            right_norm += right_value * right_value

        if left_norm == 0.0 or right_norm == 0.0:
            return 0.0

        return numerator / (math.sqrt(left_norm) * math.sqrt(right_norm))

    async def detect_topics(self, post_embedding: list[float]) -> list[dict[str, float | str]]:
        topic_embeddings = self._get_known_topic_embeddings()
        await self.repo.ensure_topics(topic_embeddings)

        ranked_topics = sorted(
            (
                {
                    "topic_name": topic_name,
                    "confidence": self._cosine_similarity(post_embedding, topic_embedding),
                }
                for topic_name, topic_embedding in topic_embeddings.items()
            ),
            key=lambda topic: topic["confidence"],
            reverse=True,
        )

        return [
            topic
            for topic in ranked_topics[:AI_TOPIC_MATCH_LIMIT]
            if topic["confidence"] >= AI_TOPIC_SIMILARITY_THRESHOLD
        ]
