class FeedService:
    def __init__(self, repo: FeedRepository):
        self.repo = repo

    def getSimilarPosts(self):
        similarPosts = self.repo.getSimilarPosts()
        # theoretically similarity choices/logic could go here
        return similarPosts
    
    ### FUTURE: opposite posts, potential interesting topics, etc.

    '''
    NOTE: Currently this replaces the graph service since there
          is no need for it at the moment
          However, it could be added in the future
    '''