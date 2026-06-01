from fastapi import APIRouter, Depends
from ...services.interaction_service import InteractionService

router = APIRouter()

@router.get("/{id}")
def getUserInteractions(id: int, service: InteractionService = Depends()):
    return InteractionService.getUserInteractions()