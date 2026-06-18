import random
import datetime
from typing import List


class PreferenceService:
    def updateFromInteractions(self, prefs, interactions):
        topicScores = {}

        for i in interactions:
            if i.liked:
                topicScores[i.topic] = topicScores.get(i.topic, 0) + 1

            if prefs.use_view_time:
                topicScores[i.topic] = topicScores.get(i.topic, 0) + (i.view_time * prefs.view_time_weight)

        sortedTopics = sorted(topicScores.items(), key=lambda x: x[1], reverse=True)

        prefs.preferredTopics = [t[0] for t in sortedTopics[:5]]

        return prefs


class RankingService:
    def score(self, post, similarity: float):
        recencyBoost = 1 / (1 + (datetime.datetime.now() - post["created_at"]))
        return similarity * 0.7 + recencyBoost * 0.3

    def applyPreferences(self, prefs, posts: List[str]):
        filtered = []

        for post in posts:
            if post["topic"] in prefs.blacklisted_topics:
                continue

            score = post.get("similarity", 0)

            if post["topic"] in prefs.preferred_topics:
                score += 0.3

            score += random.random() * prefs.randomness

            post["score"] = score
            filtered.append(post)

        return sorted(filtered, key=lambda p: p["score"], reverse=True)


class StrategyService:
    def __init__(self, repo, service):
        self.repo = repo
        self.service = service

    async def getCandidates(self, embedding, prefs):
        strategies = []

        if prefs.strategy_weights.get("similar", 0) > 0:
            similar = await self.repo.getSimilarPosts(embedding, limit=10)
            strategies.append(("similar", similar))

        if prefs.strategy_weights.get("opposite", 0) > 0:
            opposite = await self.repo.get_opposite_posts(embedding, limit=10)
            strategies.append(("opposite", opposite))

        if prefs.strategy_weights.get("graph", 0) > 0:
            base = await self.repo.getSimilarPosts(embedding, limit=5)
            expandedIds = await self.service.expandPosts(base)
            graphPosts = await self.repo.getPostsByIds(expandedIds)
            strategies.append(("graph", graphPosts))

        if prefs.strategy_weights.get("random", 0) > 0:
            randomPosts = await self.repo.getRandomPosts(limit=10)
            strategies.append(("random", randomPosts))

        return strategies


class FeedService:
    def __init__(self,
                 repo,
                 GraphService: GraphService,
                 RankingService: RankingService,
                 EmbeddingService,
                 StrategyService: StrategyService,
                 PreferenceService: PreferenceService,
                 PrefRepo,
                 InteractionRepo
                 ):
        self.repo = repo
        self.GraphService = GraphService
        self.RankingService = RankingService
        self.EmbeddingService = EmbeddingService
        self.StrategyService = StrategyService
        self.PreferenceService = PreferenceService
        self.PrefRepo = PrefRepo
        self.InteractionRepo = InteractionRepo

    async def getFeed(self, userId: int, userInput: str):
        prefs = await self.PrefRepo.getPrefs(userId)
        interactions = await self.InteractionRepo.getRecentInteractions(userId)
        prefs = self.PreferenceService.updateFromInteractions(prefs, interactions)

        embedding = EmbeddingService.embedText(userInput)

        strategyResults = await self.StrategyService.getCandidates(embedding, prefs)

        seeds = []
        for strategyName, posts in strategyResults:
            for p in posts:
                p["_strategy"] = strategyName
                seeds.append(p)

        seedPosts = seeds[:10]
        expandedIds = await self.GraphService.expandPosts(seedPosts)
        allIds = set(p["id"] for p in seedPosts) | set(expandedIds)

        expandedPosts = self.repo.getPostsByIds(list(allIds))

        seedMap = {p["id"]: p for p in seeds}

        for post in expandedPosts:
            if post["id"] in seedMap:
                post["similarity"] = seedMap[post["id"]].get("similarity", 0)
                post["_strategy"] = seedMap[post["id"]].get("_strategy", "graph")
            else:
                post["similarity"] = 0.3
                post["_strategy"] = "graph"

        weighted = []
        for post in expandedPosts:
            strategy = post.get("_strategy", "graph")
            weight = prefs.strategy_weights.get(strategy, 0.1)
            post["score"] = post["similarity"] * weight
            weighted.append(post)

        ranked = self.RankingService.applyPreferences(prefs, weighted)

        return ranked[:20]

    async def getNewSessionPosts(self, userId: int):
        prefs = await self.PrefRepo.getPrefs(userId)
        return await self.repo.getNewSessionPosts(prefs.diversityTolerance, [], None)