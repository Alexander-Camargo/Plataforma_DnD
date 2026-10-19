"""
Archivo: rules.py
Propósito: Router de FastAPI para la consulta del catálogo mecánico y reglas de creación de personajes D&D 5e.
Creador: Joshua Pérez Bullen
Modificaciones / Actualizaciones:
- 2026-10-12 [Joshua Pérez Bullen]: Creación del endpoint /creation.
- 2026-10-18 [Alexander Camargo]: Inyección de dependencia get_db para consultar el catálogo directamente desde la base de datos relacional.
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.api.deps import get_current_user, get_db
from app.services.rules_catalog import creation_catalog

router = APIRouter()


@router.get("/creation")
def get_creation_catalog(db: Session = Depends(get_db), _user=Depends(get_current_user)):
    """Catálogo mecánico de creación; las hojas siguen utilizando claves españolas."""
    return creation_catalog(db)
