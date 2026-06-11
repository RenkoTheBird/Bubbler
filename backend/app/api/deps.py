from fastapi import Depends, Request

# --- Pool ---
def getPool(request: Request):
    return request.app.state.pool

# --- Repository DB accesses ---
from ..repositories.auth_repo import AuthRepository
from ..repositories.feed_repo import FeedRepository
from ..repositories.graph_repo import GraphRepository
from ..repositories.interaction_repo import InteractionRepository
from ..repositories.post_repo import PostRepository
from ..repositories.user_pref_repo import UserPreferencesRepository
from ..repositories.user_repo import UserRepository

def getAuthRepo(pool = Depends(getPool)):
    return AuthRepository(pool)
def getFeedRepo(pool = Depends(getPool)):
    return FeedRepository(pool)
def getGraphRepo(pool = Depends(getPool)):
    return GraphRepository(pool)
def getInteractionRepo(pool = Depends(getPool)):
    return InteractionRepository(pool)
def getPostRepo(pool = Depends(getPool)):
    return PostRepository(pool)
def getUserPrefRepo(pool = Depends(getPool)):
    return UserPreferencesRepository(pool)
def getUserRepo(pool = Depends(getPool)):
    return UserRepository(pool)

# --- Services ---
from ..services.auth_service import AuthService
from ..services.embedding_service import EmbeddingService
from ..services.feed_service import FeedService
from ..services.graph_service import GraphService
from ..services.interaction_service import InteractionService
from ..services.password_service import PasswordService
from ..services.post_service import PostService
from ..services.preference_service import PreferenceService
from ..services.ranking_service import RankingService
from ..services.strategy_service import StrategyService
from ..services.user_service import UserService

def getEmbeddingService():
    return EmbeddingService()

def getGraphService(repo: GraphRepository = Depends(getGraphRepo)):
    return GraphService(repo)

def getInteractionService(repo: InteractionRepository = Depends(getInteractionRepo)):
    return InteractionService(repo)

def getPasswordService():
    return PasswordService()

def getAuthService(
        repo: AuthRepository = Depends(getAuthRepo),
        service: PasswordService = Depends(getPasswordService),
):
    return AuthService(repo, service)

def getPostService(
        repo: PostRepository = Depends(getPostRepo), 
        service: EmbeddingService = Depends(getEmbeddingService),
        ):
    return PostService(repo, service)

def getPreferenceService():
    return PreferenceService()

def getRankingService():
    return RankingService()

def getStrategyService(
        repo: FeedRepository = Depends(getFeedRepo), 
        service: GraphService = Depends(getGraphService),
        ):
    return StrategyService(repo, service)

def getUserService(repo: UserRepository = Depends(getUserRepo)):
    return UserService(repo)

# --- THE CORE: Feed service ---
def getFeedService(
        repo: FeedRepository = Depends(getFeedRepo),
        GraphService: GraphService = Depends(getGraphService),
        RankingService: RankingService = Depends(getRankingService),
        EmbeddingService: EmbeddingService = Depends(getEmbeddingService),
        StrategyService: StrategyService = Depends(getStrategyService),
        PreferenceService: PreferenceService = Depends(getPreferenceService),
        PrefRepo: UserPreferencesRepository = Depends(getUserPrefRepo),
        InteractionRepo: InteractionRepository = Depends(getInteractionRepo),
):
    return FeedService(
        repo,
        GraphService,
        RankingService,
        EmbeddingService,
        StrategyService,
        PreferenceService,
        PrefRepo,
        InteractionRepo
    )