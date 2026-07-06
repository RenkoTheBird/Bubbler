class GraphService:
    def __init__(self, repo):
        self.repo = repo  # feed repo

    async def expand_posts(self, seedPosts: list, depth: int = 1, *, conn=None):
        visited: set[str] = set()
        results: list[str] = []

        async def expand_level(post_ids: list[str], current_depth: int) -> None:
            if current_depth > depth or not post_ids:
                return

            unvisited = [pid for pid in post_ids if pid not in visited]
            for pid in unvisited:
                visited.add(pid)

            if not unvisited:
                return

            batch = await self.repo.get_neighbors_batch(unvisited, conn=conn)
            next_ids: list[str] = []

            for pid in unvisited:
                for neighbor in batch.get(str(pid), []):
                    nid = neighbor["to_post_id"]
                    results.append(nid)
                    if nid not in visited:
                        next_ids.append(nid)

            await expand_level(next_ids, current_depth + 1)

        seed_ids = [str(p["id"]) for p in seedPosts]
        await expand_level(seed_ids, 0)
        return results
