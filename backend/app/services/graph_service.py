from ..repositories.graph_repo import GraphRepository
from typing import List

class GraphService:

    def __init__(self, repo: GraphRepository):
        self.repo = repo

    async def expandPosts(self, seedPosts: List[str], depth: int=1):
        visited = set()
        results = []

        async def dfs(postId: int, currentDepth: int):
            if currentDepth > depth or postId in visited:
                return
            
            visited.add(postId)

            neighbors = await self.repo.getNeighbors(postId)

            for neighbor in neighbors:
                results.append(neighbor["to_post_id"])
                await dfs(neighbor["to_post_id"], currentDepth + 1)

        for post in seedPosts:
            await dfs(post["id"], 0)

        return results

    

    