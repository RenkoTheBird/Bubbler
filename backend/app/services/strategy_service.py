class StrategyService:

    def __init__(self, repo = FeedRepository, service = GraphService):
        self.repo = repo
        self.service = service
    
    async def getCandidates(self, embedding, prefs):
        strategies = []

        # Similar posts
        if prefs.strategy_weights.get("similar", 0) > 0:
            similar = await self.repo.getSimilarPosts(embedding, limit=10)
            strategies.append(("similar", similar))

        # Opposite posts w/ low similarity
        if prefs.strategy_weights.get("opposite", 0) > 0:
            # NOTE: There is no get opposite posts function yet
            pass

        # Domain expansion (the graph. I mean the graph.)
        if prefs.strategy_weights.get("graph", 0) > 0:
            base = await self.repo.getSimilarPosts(embedding, limit=5)
            expandedIds = await self.service.expandPosts(base)
            # TODO: add getPostsByIds function
            graphPosts = await self.repo.getPostsByIds(expandedIds)
            strategies.append(("graph", graphPosts))

        # Random posts
        if prefs.strategy_weights.get("random", 0) > 0:
            # TODO: add getRandomPosts function
            randomPosts = await self.repo.getRandomPosts(limit=10)
            strategies.append(("random", randomPosts))

        return strategies