from ..models.interaction import Interaction

class InteractionRepository:
    def __init__(self, pool):
        self.pool = pool