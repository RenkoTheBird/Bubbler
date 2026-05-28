from backend.app.main import app
from typing import List
'''
GOAL: When viewing user profile, retrieve their data
'''
@app.get("users/{id}/profile")
async def getProfileInfo(id: str):

    async with app.state.pool.acquire() as conn:
        data = await conn.fetch(
            """SELECT * FROM users WHERE id = $1""", id
        )

    return data

'''
GOAL: allow user to change their email
'''
@app.put("users/{id}/profile/email")
async def putEmail(email: str, id: str):

    async with app.state.pool.acquire() as conn:
        data = await conn.fetch(
            """UPDATE users SET email = $1 WHERE id = $2""", email, id
        )

    return data

'''
TODO: Goal: get user's daily bubbles (shows upon launching app)
---- Option 1: take 1 post they liked yesterday 
---- Option 2: take 1 post from a topic they liked
Base cosine simlarity on this
'''

@app.get("users/{id}/session")
async def getNewSessionPosts(diversityTolerance: int, yesterdayPost: List[float], likedTopic: str):
    savedVal = 1 - (diversityTolerance * 0.01 + 0.10)
    val = 1
    similarityTargets = []
    for i in range(4): # Retrieve 4 posts
        similarityTargets.append(val)
        val -= savedVal

    results = []

    async with app.state.pool.acquire() as conn:
        for target in similarityTargets:
            post = await conn.fetchrow("""
                                        SELECT *
                                            1 - (embedding <=> $1::vector) AS similarity
                                        FROM posts
                                        WHERE topic = $2
                                        ORDER BY ABS((1 - (embedding <=> $1::vector)) - $3)
                                        LIMIT 1
                                       """,
                                       yesterdayPost,
                                       likedTopic,
                                       target)
            
            if post:
                results.append(dict(post))
            
            return results

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