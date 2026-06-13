from fastapi import APIRouter, Depends
from ...services.interaction_service import InteractionService
from ..deps import getInteractionService

router = APIRouter()

@router.get("/{id}")
def getUserInteractions(id: int, service: InteractionService = Depends(getInteractionService)):
    return InteractionService.getUserInteractions()