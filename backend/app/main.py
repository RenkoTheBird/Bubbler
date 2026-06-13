from fastapi import FastAPI
from contextlib import asynccontextmanager
import asyncpg

# --- On startup: Create pool ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Runs once at startup and shutdown.

    app.state.pool = await asyncpg.create_pool(
        user="REPLACE",
        password="THISTOO",
        database="NAME",
        host="IP",
        port="NUMBER",
        min_size=1,
        max_size=10
    )

    yield

    await app.state.pool.close()

app = FastAPI(lifespan=lifespan)


# Routing #
from .api.routes import auth, feed, posts, users, interactions

app.include_router(auth.router, prefix="/auth")
app.include_router(feed.router, prefix="/feed")
app.include_router(posts.router, prefix="/posts")
app.include_router(users.router, prefix="/users")
app.include_router(interactions.router, prefix="/interactions")