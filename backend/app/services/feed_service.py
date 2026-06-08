from ..repositories.feed_repo import FeedRepository
from typing import List
from .embedding_service import EmbeddingService
from ..services.graph_service import GraphService
from ..services.ranking_service import RankingService

class FeedService:
    def __init__(self, repo: FeedRepository, GraphService: GraphService, RankingService: RankingService, EmbeddingService: EmbeddingService):
        self.repo = repo
        self.GraphService = GraphService
        self.RankingService = RankingService
        self.EmbeddingService = EmbeddingService

    async def getFeed(self, userInput: str):
        # user input allows user to customize the output
        embedding = EmbeddingService.embed_text(userInput)
        
        # get (four right now) similar posts with pgvector search
        similarPosts = await self.repo.getSimilarPosts(embedding)

        # expand these results via graph
        expandedIds = await self.GraphService.expandPosts(similarPosts)

        # fetch the expanded posts
        expandedPosts = []
        for postId in expandedIds:
            posts = await self.repo.getSimilarPosts(embedding, limit=1)
            expandedPosts.extend(posts)

        # Score and rank the posts
        scored = []
        for post in expandedPosts:
            score = self.RankingService.score(post, post.get("similarity", 0))
            post["score"] = score
            scored.append(post)

        return self.RankingService.rank(scored)
    
    async def getNewSessionPosts(self):
        return await self.repo.getNewSessionPosts()
    
    ### FUTURE: opposite posts, potential interesting topics, etc.
