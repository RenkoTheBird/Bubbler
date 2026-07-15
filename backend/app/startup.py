from config import my_env_vars
from contextlib import asynccontextmanager
from fastapi import FastAPI
import asyncpg
import logging

# Routes
from app.routes.auth import create_auth_router
from app.routes.feed import create_feed_router
from app.routes.graph import create_graph_router
from app.routes.system import create_system_router
from app.routes.user import create_user_router

# Services
from app.services.auth import AuthService
from app.services.feed import FeedService
from app.services.feed import PreferenceService
from app.services.feed import RankingService
from app.services.feed import StrategyService
from app.services.graph import GraphService
from app.services.interaction import InteractionService
from app.services.post import EmbeddingService
from app.services.post import PostService
from app.services.topic_detection import TopicDetectionService
from app.services.user import UserService

# Repositories
from .repositories.auth_repo import AuthRepository
from .repositories.edge_builder_repo import EdgeBuilderRepo
from .repositories.feed_repo import FeedRepository
from .repositories.interaction_repo import InteractionRepository
from .repositories.post_repo import PostRepository
from .repositories.user_repo import UserRepository

# Dependencies
from app.deps import get_current_user_id

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
        pool = await asyncpg.create_pool(my_env_vars.db_url, min_size=1, max_size=5)
        logger.info("Database pool created successfully")
    except Exception as exc:
        logger.error(f"Failed to create database pool: {exc}")
        raise

    # Repositories
    auth_repo = AuthRepository(pool)
    feed_repo = FeedRepository(pool)
    post_repo = PostRepository(pool)
    user_repo = UserRepository(pool)
    interaction_repo = InteractionRepository(pool)
    edge_builder_repo = EdgeBuilderRepo(pool)

    # Start services
    auth_service = AuthService(auth_repo, my_env_vars.secret_key, my_env_vars.algorithm, my_env_vars.timeoffset)
    graph_service = GraphService(feed_repo)
    interaction_service = InteractionService(interaction_repo)
    embedding_service = EmbeddingService()
    embedding_service.preload()
    logger.info("Embedding model loaded (single API worker owns the model)")
    topic_detection_service = TopicDetectionService(post_repo, embedding_service)
    post_service = PostService(post_repo, edge_builder_repo, embedding_service, topic_detection_service)
    user_service = UserService(user_repo)
    strategy_service = StrategyService(feed_repo)
    feed_service = FeedService(feed_repo, graph_service, RankingService(), embedding_service, strategy_service,
                               PreferenceService(), user_repo, interaction_repo)

    # start routers
    auth_router = create_auth_router(auth_service)
    feed_router = create_feed_router(feed_service, get_current_user_id)
    graph_router = create_graph_router(feed_service, get_current_user_id)  # graph routes use feed service
    system_router = create_system_router(pool)
    user_router = create_user_router(user_service, interaction_service, post_service, get_current_user_id)

    # register routers
    fastapi.include_router(auth_router, prefix="/auth", tags=["auth"])
    fastapi.include_router(feed_router, prefix="/feed", tags=["feed"])
    fastapi.include_router(graph_router, prefix="/graph", tags=["graph"])
    fastapi.include_router(system_router, tags=["system"])
    fastapi.include_router(user_router, prefix="/user", tags=["user"])

    yield
    try:
        await pool.close()
        logger.info("Database pool closed")
    except Exception as exc:
        logger.error(f"Error closing the database pool: {exc}")
        raise
