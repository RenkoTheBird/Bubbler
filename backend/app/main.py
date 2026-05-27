from fastapi import FastAPI
from backend.app.api.routes import auth
from backend.app.api.routes import feed
from backend.app.api.routes import graph
from backend.app.api.routes import posts
from backend.app.api.routes import users

app = FastAPI()
app.include_router(auth.router, prefix="/auth")
app.include_router(feed.router, prefix="/feed")
app.include_router(graph.router, prefix="/graph")
app.include_router(posts.router, prefix="/posts")
app.include_router(users.router, prefix="/users")

@app.get("/")
def readRoot():
    return {"user": "user"}