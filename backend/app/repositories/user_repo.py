from ..schemas.user import UserProfile

DEFAULT_PREFS = UserProfile(
    user_id=0,
    diversity_tolerance=0.4,
    randomness=0.3,
    preferred_topics=[],
    blacklisted_topics=[],
    strategy_weights={
        "similar": 0.7,
        "graph": 0.2,
        "opposite": 0.0,
        "random": 0.1,
    },
)

# GOAL: When viewing user profile, retrieve their data
class UserRepository:
    def __init__(self, pool):
        self.pool = pool

    async def get_profile_info(self, id: int):

        async with self.pool.acquire() as conn:
            data = await conn.fetch(
                """SELECT * FROM users WHERE id = $1""", id
            )

        return data

    # GOAL: allow user to change their email
    async def put_email(self, email: str, id: int):

        async with self.pool.acquire() as conn:
            data = await conn.fetch(
                """UPDATE users SET email = $1 WHERE id = $2""", email, id
            )

        return data
    
    async def get_prefs(self, user_id: int) -> UserProfile:
        async with self.pool.acquire() as conn:
            rows = await conn.fetchrow("""SELECT * FROM user_profiles WHERE user_id = $1""", user_id)

        if not rows:
            return DEFAULT_PREFS.model_copy(update={"user_id": user_id})
        
        return UserProfile(
            user_id=rows["user_id"],
            diversity_tolerance=rows["diversity_tolerance"],
            randomness=rows["randomness"],
            preferred_topics=list(rows["preferred_topics"]),
            blacklisted_topics=list(rows["blacklisted_topics"]),
            use_view_time=rows["use_view_time"],
            view_time_weight=rows["view_time_weight"],
            strategy_weights=dict(rows["strategy_weights"]),
        )

