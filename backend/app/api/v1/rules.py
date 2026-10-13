from fastapi import APIRouter, Depends
from app.api.deps import get_current_user
from app.services.rules_catalog import creation_catalog

router = APIRouter()


@router.get("/creation")
def get_creation_catalog(_user=Depends(get_current_user)):
    """Catálogo mecánico de creación; las hojas siguen utilizando claves españolas."""
    return creation_catalog()

