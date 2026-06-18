class InteractionService:
    def __init__(self, repo):
        self.repo = repo

    def getUserInteractions(self, id: int):
        return self.repo.getUserInteractions(id)