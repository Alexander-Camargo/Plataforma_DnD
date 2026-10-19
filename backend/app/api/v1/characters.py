"""
Archivo: characters.py
Propósito: Endpoints para la gestión del ciclo de vida de personajes (creación, lectura, actualización con bloqueo optimista, subida de nivel 5e en campaña por hitos/XP, cambio de estado narrativo por el DM y eliminación).
Creador: Alexander Camargo
Modificaciones / Actualizaciones:
- 2026-10-08 [Alexander Camargo]: Endpoints CRUD para personajes y control de estado por DM.
- 2026-10-12 [Joshua Pérez Bullen]: Validación de creación con reglas 5e y bloqueo de cambios de nivel no unitarios.
- 2026-10-18 [Alexander Camargo]: Inyección de la sesión db en creation_catalog e integración de subida de nivel 5e (apply_level_up) en update_character.
- 2026-10-18 [Alexander Camargo]: Restricción de subida de nivel exclusiva para personajes con campaña activa y experiencia (XP) requerida, más endpoint para otorgar XP por el DM.
"""
import uuid
from datetime import datetime, timezone
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_current_user
from app.schemas.api_models import (
    AwardXpIn,
    CharacterCreate,
    CharacterOut,
    CharacterStatusUpdate,
    CharacterUpdate,
)
from app.db.models import User, Character, Campaign, CampaignMember, StatusEvent

from app.services.rules_catalog import creation_catalog, find_option
from app.domain.rules import apply_level_up, calculate_creation, refresh_derived_checks, xp_for_level

router = APIRouter()


def _is_member(db: Session, campaign_id: uuid.UUID, user_id: uuid.UUID) -> bool:
    return db.query(CampaignMember).filter_by(
        campaign_id=campaign_id, user_id=user_id
    ).first() is not None


def _apply_character_level_up(char: Character, char_in: CharacterUpdate, catalog: dict) -> None:
    is_level_change = char_in.level is not None and char_in.level != char.level
    if is_level_change and char_in.level != char.level + 1:
        raise ValueError("Solo se puede subir un nivel a la vez")
    if not is_level_change and char_in.level_up is None:
        return
    if char_in.level is not None and char_in.level == char.level:
        raise ValueError("Debes incrementar el nivel para aplicar opciones de subida de nivel.")
    if char.campaign_id is None:
        raise ValueError("Los personajes sin una campaña activa no pueden subir de nivel.")

    target_level = char_in.level or (char.level + 1)
    required_xp = xp_for_level(target_level)
    if char.experience < required_xp:
        raise ValueError(
            f"El personaje requiere {required_xp} XP para subir al nivel {target_level} "
            f"(experiencia actual: {char.experience} XP). Espera a que el DM complete un hito u otorgue experiencia."
        )

    race = find_option(catalog["races"], char.race, "Raza")
    cls = find_option(catalog["classes"], char.class_slug, "Clase")
    subrace = find_option(race["subraces"], char.subrace, "Subraza") if char.subrace else None
    choices = char_in.level_up.model_dump() if char_in.level_up else None
    char.sheet = apply_level_up(catalog, race, cls, subrace, char.level, char.sheet, choices)
    char.level += 1


@router.get("/", response_model=List[CharacterOut])
def list_campaign_characters(
    campaign_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Personajes de una campaña (solo visible para sus miembros)."""
    if not _is_member(db, campaign_id, current_user.id):
        raise HTTPException(status_code=403, detail="No perteneces a esta campaña")
    return db.query(Character).filter(Character.campaign_id == campaign_id).all()


@router.get("/me", response_model=List[CharacterOut])
def my_characters(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Personajes que posee el usuario actual."""
    return (
        db.query(Character)
        .filter(Character.owner_id == current_user.id)
        .order_by(Character.created_at.desc())
        .all()
    )


@router.post("/", response_model=CharacterOut, status_code=201)
def create_character(
    char_in: CharacterCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    catalog = creation_catalog(db)
    try:
        race = find_option(catalog["races"], char_in.race, "Raza")
        cls = find_option(catalog["classes"], char_in.class_slug, "Clase")
        subrace = None
        if race["subraces"]:
            subrace = find_option(race["subraces"], char_in.subrace or "", "Subraza")
        elif char_in.subrace:
            raise ValueError("Esta raza no admite una subraza.")
        if char_in.level != 1:
            raise ValueError("El asistente crea personajes de nivel 1.")
        sheet = calculate_creation(catalog, race, cls, subrace, char_in.creation.model_dump(), char_in.sheet)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error

    char = Character(
        owner_id=current_user.id,
        name=char_in.name.strip(),
        race=race["name"],
        subrace=subrace["id"] if subrace else None,
        class_slug=cls["legacy_slug"],
        level=1,
        avatar_url=char_in.avatar_url,
        status="alive",
        status_note="",
        sheet=sheet,
    )

    db.add(char)
    db.commit()
    db.refresh(char)
    return char


@router.get("/{char_id}", response_model=CharacterOut)
def get_character(
    char_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    char = db.query(Character).filter(Character.id == char_id).first()
    if not char:
        raise HTTPException(status_code=404, detail="Personaje no encontrado")

    # Solo el dueño o los miembros de su campaña (el DM puede verla, no editarla)
    if char.owner_id != current_user.id and not (
        char.campaign_id and _is_member(db, char.campaign_id, current_user.id)
    ):
        raise HTTPException(status_code=403, detail="No tienes permiso para ver este personaje")
    return char


@router.patch("/{char_id}", response_model=CharacterOut)
def update_character(
    char_id: uuid.UUID,
    char_in: CharacterUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    char = db.query(Character).filter(Character.id == char_id).first()
    if not char:
        raise HTTPException(status_code=404, detail="Personaje no encontrado")

    # Solo el dueño edita la hoja. El DM únicamente cambia el estado (endpoint /status).
    if char.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Solo el dueño puede editar la hoja")

    # Optimistic locking
    if char.version != char_in.version:
        raise HTTPException(status_code=409, detail="El personaje fue modificado por otro usuario. Recarga la página.")

    if char_in.name is not None:
        char.name = char_in.name.strip()
    if char_in.avatar_url is not None:
        char.avatar_url = char_in.avatar_url

    if char_in.sheet is not None:
        stats = char_in.sheet.get("stats", {})
        if any(type(v) is not int or v < 1 or v > 20 for v in stats.values()):
            raise HTTPException(status_code=400, detail="Las puntuaciones deben estar entre 1 y 20")
        char.sheet = char_in.sheet

    catalog = creation_catalog(db)

    # Terminar la campaña actual: se archiva en el historial de la hoja
    if char_in.leave_campaign and char.campaign_id is not None:
        old_campaign = db.query(Campaign).filter(Campaign.id == char.campaign_id).first()
        new_sheet = dict(char.sheet or {})
        history = list(new_sheet.get("campaign_history", []))
        history.append({
            "id": str(char.campaign_id),
            "name": old_campaign.name if old_campaign else "Campaña eliminada",
            "finished_at": datetime.now(timezone.utc).isoformat(),
            "final_status": char.status,
        })
        new_sheet["campaign_history"] = history
        char.sheet = new_sheet
        char.campaign_id = None

    try:
        _apply_character_level_up(char, char_in, catalog)
        char.sheet = refresh_derived_checks(char.sheet, char.level, catalog)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    char.version += 1
    db.commit()
    db.refresh(char)
    return char


@router.patch("/{char_id}/status", response_model=CharacterOut)
def update_character_status(
    char_id: uuid.UUID,
    status_in: CharacterStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    char = db.query(Character).filter(Character.id == char_id).first()
    if not char:
        raise HTTPException(status_code=404, detail="Personaje no encontrado")

    if not char.campaign_id:
        raise HTTPException(status_code=400, detail="El personaje no está en una campaña")

    # Only DM can change status
    campaign = db.query(Campaign).filter(Campaign.id == char.campaign_id).first()
    if not campaign or campaign.dm_id != current_user.id:
        raise HTTPException(status_code=403, detail="Solo el DM puede cambiar el estado")

    db.add(StatusEvent(
        campaign_id=char.campaign_id,
        character_id=char.id,
        changed_by=current_user.id,
        old_status=char.status,
        new_status=status_in.status,
        note=status_in.status_note or "",
    ))
    char.status = status_in.status
    char.status_note = status_in.status_note or ""
    try:
        char.sheet = refresh_derived_checks(char.sheet, char.level, creation_catalog(db))
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    char.version += 1
    db.commit()
    db.refresh(char)
    return char


@router.post("/{char_id}/award-xp", response_model=CharacterOut)
def award_character_xp(
    char_id: uuid.UUID,
    xp_in: AwardXpIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """El DM otorga o suma puntos de experiencia (XP) a un personaje de su campaña."""
    char = db.query(Character).filter(Character.id == char_id).first()
    if not char:
        raise HTTPException(status_code=404, detail="Personaje no encontrado")
    if not char.campaign_id:
        raise HTTPException(status_code=400, detail="El personaje no está en una campaña activa")

    campaign = db.query(Campaign).filter(Campaign.id == char.campaign_id).first()
    if not campaign or campaign.dm_id != current_user.id:
        raise HTTPException(status_code=403, detail="Solo el DM de la campaña puede otorgar experiencia")

    char.experience += xp_in.xp
    char.version += 1
    db.commit()
    db.refresh(char)
    return char


@router.delete("/{char_id}", status_code=204)
def delete_character(
    char_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    char = db.query(Character).filter(Character.id == char_id).first()
    if not char:
        raise HTTPException(status_code=404, detail="Personaje no encontrado")
    if char.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Solo el dueño puede eliminar el personaje")
    if char.campaign_id is not None:
        raise HTTPException(status_code=409, detail="Termina la campaña activa antes de eliminar al personaje")
    db.delete(char)
    db.commit()
