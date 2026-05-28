class userService:
    def __init__(self, repo: ServiceRepository):
        self.repo = repo
    
    def getProfileInfo(self):
        info = self.repo.getProfileInfo()
        return info
    
    def getNewSessionPosts(self):
        posts = self.repo.getNewSessionPosts()
        return posts

    def putEmail(self):
        email = self.repo.putEmail()
        return email
