from backend.app.main import app

'''
TODO: Goal: get user's daily bubbles (shows upon launching app)
'''

@app.get("users/{id}/session")
async def getNewSessionPosts(diversityTolerance: int):
    
    async with app.state.pool.acquire as conn:
        pass


'''
How are the posts retrieved?
- Based upon diversity tolerance, (value between 0-65), calculate the disparity
- 65 tolerance -- space out by similarity (1, 0.25, -0.25, -1)
- 0 tolerance -- hover toward higher end (1, 0.9, 0.8, 0.7)
- so the gap should be between 0.75 and 0.1 going down
- Example: if tolerance is 65
- Post 1: 1
- Post 2: post1 - (tolerance * 0.01 + 0.10) = 0.25
- savedVal = tolerance * 0.01 + 0.10
- Post 3: post2 - savedVal
- Post 4: post3 - savedVal
'''