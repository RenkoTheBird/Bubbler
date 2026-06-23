from config import my_env_vars
from contextlib import asynccontextmanager
from fastapi import FastAPI
import asyncpg
import logging

# Routes
from app.routes.auth import create_auth_router
from app.routes.graph import create_graph_router
from app.routes.feed import create_feed_router
from app.routes.user import create_user_router

# Services
from app.services.auth import AuthService
from app.services.feed import FeedService
from app.services.feed import StrategyService
from app.services.feed import RankingService
from app.services.feed import PreferenceService
from app.services.graph import GraphService
from app.services.interaction import InteractionService
from app.services.post import PostService
from app.services.post import EmbeddingService
from app.services.user import UserService

# Repositories
from .repositories.auth_repo import AuthRepository
from .repositories.edge_builder_repo import EdgeBuilderRepo
from .repositories.feed_repo import FeedRepository
from .repositories.interaction_repo import InteractionRepository
from .repositories.post_repo import PostRepository
from .repositories.user_repo import UserRepository

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

    # Repositories
    auth_repo = AuthRepository(pool)
    
    # Start services 
    auth_service = AuthService(pool, my_env_vars.secret_key, my_env_vars.algorithm, my_env_vars.timeoffset)
    graph_service = GraphService(FeedRepository)
    interaction_service = InteractionService(InteractionRepository)
    post_service = PostService(PostRepository)
    user_service = UserService(UserRepository)
    strategy_service = StrategyService(FeedRepository, GraphService)
    feed_service = FeedService(FeedRepository, graph_service, RankingService, EmbeddingService, strategy_service,
                               PreferenceService, UserRepository, InteractionRepository)
    
    #start routers 
    auth_router = create_auth_router(auth_service)
    feed_router = create_feed_router(feed_service)
    graph_router = create_graph_router(feed_service) # not a typo
    user_router = create_user_router(user_service, interaction_service, post_service)

    #register routers 
    fastapi.include_router(auth_router)
    fastapi.include_router(feed_router)
    fastapi.include_router(graph_router)
    fastapi.include_router(user_router)
    
    yield
    try:
        await pool.close()
        logger.info("Database pool closed")
    except Exception as exc:
        logger.error(f"Error closing the database pool: {exc}")
        raise