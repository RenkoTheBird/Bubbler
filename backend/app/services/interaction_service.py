class InteractionService:
    def __init__(self, repo: InteractionRepository):
        self.repo = repo

    def getUserInteractions(self, id: int):
        return self.repo.getUserInteractions(id)