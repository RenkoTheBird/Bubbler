from fastapi import APIRouter, HTTPException


def create_system_router(pool):
    router = APIRouter()

    @router.get("/health")
    async def get_health():
        try:
            await pool.fetchval("SELECT 1")
        except Exception as exc:
            raise HTTPException(
                status_code=503,
                detail={
                    "status": "error",
                    "database": "unavailable",
                },
            ) from exc

        return {
            "status": "ok",
            "database": "connected",
        }

    return router
