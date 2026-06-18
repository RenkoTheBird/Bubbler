from config import my_env_vars
from app.services.auth import AuthService
from app.routes.auth import create_auth_router
from contextlib import asynccontextmanager
from fastapi import FastAPI
import asyncpg
import logging


# grab logger 
logger = logging.getLogger(__name__)

# configure universal logger 
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler()
    ]
)


@asynccontextmanager
async def lifespan(fastapi: FastAPI):
    try:
        pool = await asyncpg.create_pool(my_env_vars.db_url)
        logger.info("Database pool created successfully")
    except Exception as exc:
        logger.error(f"Failed to create database pool: {exc}")
        raise
    
    # Start services 
    auth_service = AuthService(pool)
    
    #start routers 
    auth_router = create_auth_router(auth_service)
    
    #register routers 
    fastapi.include_router(auth_router)
    
    
    yield
    try:
        await pool.close()
        logger.info("Database pool closed")
    except Exception as exc:
        logger.error(f"Error closing the database pool: {exc}")
        raise