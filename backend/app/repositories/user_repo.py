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