from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.api.deps import get_current_user, get_db
from app.services.rules_catalog import creation_catalog
from app.db.models import DndRace, DndClass, DndBackground, DndSkill

router = APIRouter()


@router.get("/creation")
def get_creation_catalog(db: Session = Depends(get_db), _user=Depends(get_current_user)):
    """Catálogo mecánico de creación; las hojas siguen utilizando claves españolas."""
    return creation_catalog(db)


@router.get("/races")
def list_races(db: Session = Depends(get_db), _user=Depends(get_current_user)):
    """Listado de razas y subrazas almacenadas en la base de datos."""
    return db.query(DndRace).all()


@router.get("/classes")
def list_classes(db: Session = Depends(get_db), _user=Depends(get_current_user)):
    """Listado de clases almacenadas en la base de datos."""
    return db.query(DndClass).all()


@router.get("/backgrounds")
def list_backgrounds(db: Session = Depends(get_db), _user=Depends(get_current_user)):
    """Listado de trasfondos almacenados en la base de datos."""
    return db.query(DndBackground).all()


@router.get("/skills")
def list_skills(db: Session = Depends(get_db), _user=Depends(get_current_user)):
    """Listado de habilidades oficiales almacenadas en la base de datos."""
    return db.query(DndSkill).all()
