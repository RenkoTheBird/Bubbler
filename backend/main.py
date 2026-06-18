from app.startup import lifespan
from fastapi import FastAPI

# Creates instance of the app
app = FastAPI(lifespan= lifespan)