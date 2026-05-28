from fastapi import FastAPI
from .api.routes import auth, feed, graph, posts, users

app = FastAPI()
app.include_router(auth.router, prefix="/auth")
app.include_router(feed.router, prefix="/feed")
app.include_router(graph.router, prefix="/graph")
app.include_router(posts.router, prefix="/posts")
app.include_router(users.router, prefix="/users")

@app.get("/")
def readRoot():
    return {"user": "user"}