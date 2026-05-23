from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def readRoot():
    return {"user": "user"}