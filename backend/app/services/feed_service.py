class FeedService:
    def __init__(self, 
                 repo: FeedRepository, 
                 GraphService: GraphService, 
                 RankingService: RankingService, 
                 EmbeddingService: EmbeddingService,
                 StrategyService: StrategyService,
                 PreferenceService: PreferenceService,
                 PrefRepo: UserPrefRepository,
                 InteractionRepo: InteractionRepository
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
        # Load & adapt user preferences
        prefs = await self.PrefRepo.getPrefs(userId)
        interactions = await self.InteractionRepo.getRecentInteractions(userId)
        prefs = self.PreferenceService.updateFromInteractions(prefs, interactions)
        
        # user input allows user to customize the output
        embedding = EmbeddingService.embedText(userInput)
        
        # Multi strategy seeds
        strategyResults = await self.StrategyService.getCandidates(embedding, prefs)

        # Flatten seeds & keep strategy
        seeds = []

        for strategyName, posts in strategyResults:
            for p in posts:
                p["_strategy"] = strategyName
                seeds.append(p)

        # expand these results via graph
        seedPosts = seeds[:10] # limit expansion size for MVP
        expandedIds = await self.GraphService.expandPosts(seedPosts)
        allIds = set(p["id"] for p in seedPosts) | set(expandedIds) # include original seeds

        # fetch expanded posts smoothly
        expandedPosts = self.repo.getPostsByIds(list(allIds))

        # Attach base similarity if missing
        seedMap = {p["id"]: p for p in seeds}

        for post in expandedPosts:
            if post["id"] in seedMap:
                post["similarity"] = seedMap[post["id"]].get("similarity", 0)
                post["_strategy"] = seedMap[post["id"]].get("_strategy", "graph")
            else:
                # graph-expanded nodes default lower similarity
                post["similarity"] = 0.3
                post["_strategy"] = "graph"

        # Apply strategy weights
        weighted = []

        for post in expandedPosts:
            strategy = post.get("_strategy", "graph")
            weight = prefs.strategy_weights.get(strategy, 0.1)

            post["score"] = post["similarity"] * weight
            weighted.append(post)

        # Apply user preferences
        ranked = self.RankingService.applyPreferences(prefs, weighted)

        # Finally, sort the posts
        return ranked[:20]
    
    async def getNewSessionPosts(self, userId: int):
        prefs = await self.PrefRepo.getPrefs(userId)
        return await self.repo.getNewSessionPosts(prefs.diversityTolerance, [], None)
    
    ### FUTURE: opposite posts, potential interesting topics, etc.
