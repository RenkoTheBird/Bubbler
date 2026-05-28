class PostService:
    def __init__(self, repo: PostRepository):
        self.repo = repo

    def getPosts(self):
        posts = self.repo.getPosts()
        # ranking/filtering skipped because the database calls do that
        return posts
    
    def postPosts(self):
        posts = self.repo.postPosts()
        return posts

    