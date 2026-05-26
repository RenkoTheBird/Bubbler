from backend.app.main import app
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