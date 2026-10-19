"""
Archivo: api_models.py
Propósito: Esquemas Pydantic para validación estricta de entrada y salida de datos en la API (Autenticación, Campañas, Creación y Subida de Nivel de Personajes).
Creador: Alexander Camargo
Modificaciones / Actualizaciones:
- 2026-10-08 [Alexander Camargo]: Esquemas base de usuarios, campañas, personajes y estados.
- 2026-10-11 [Alexander Camargo]: Validación de requisitos de contraseña segura en UserCreate.
- 2026-10-12 [Joshua Pérez Bullen]: Incorporación de CharacterCreationChoices con validación estricta de enteros.
- 2026-10-18 [Alexander Camargo]: Incorporación de LevelUpChoices para el flujo de subida de nivel guiada y ASI (Hito 3.1).
- 2026-10-18 [Alexander Camargo]: Esquemas para Hitos de campaña (MilestoneCreate, MilestoneOut, MilestoneUpdate), esquema AwardXpIn y persistencia de experience en Character.
"""
import re
import uuid
from datetime import datetime
from typing import Any, Literal, Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

# Estados narrativos que puede asignar el DM
CharacterStatus = Literal["alive", "dead", "undead", "resurrected", "race_changed", "lost"]


# --- Auth ---
class UserCreate(BaseModel):
    username: str = Field(min_length=3, max_length=32, pattern=r"^[\w.\-]+$")
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)

    @field_validator("password")
    @classmethod
    def validate_secure_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("La contraseña debe tener al menos 8 caracteres.")
        if not re.search(r"[A-Z]", v):
            raise ValueError("La contraseña debe contener al menos una letra mayúscula.")
        if not re.search(r"[a-z]", v):
            raise ValueError("La contraseña debe contener al menos una letra minúscula.")
        if not re.search(r"\d", v):
            raise ValueError("La contraseña debe contener al menos un número.")
        if not re.search(r'[!@#$%^&*(),.?":{}|<>\-_=+[\]\\/;`~]', v):
            raise ValueError("La contraseña debe contener al menos un carácter especial.")
        return v

class UserLogin(BaseModel):
    # Nombre de usuario O correo electrónico
    identifier: str = Field(min_length=1, max_length=254)
    password: str = Field(min_length=1, max_length=128)

class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

class UserOut(BaseModel):
    id: uuid.UUID
    username: str
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


# --- Campaigns ---
class CampaignCreate(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    description: Optional[str] = ""

class CampaignOut(BaseModel):
    id: uuid.UUID
    name: str
    description: str
    # Solo se rellena para el DM; los jugadores reciben cadena vacía.
    dm_notes: str = ""
    join_code: str
    dm_id: uuid.UUID
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

class CampaignJoin(BaseModel):
    join_code: str
    character_id: uuid.UUID

class CampaignUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=80)
    description: Optional[str] = None
    dm_notes: Optional[str] = None


# --- Campaign Milestones ---
class MilestoneBase(BaseModel):
    title: str = Field(min_length=1, max_length=120)
    description: str = ""
    target_level: int = Field(default=2, ge=2, le=20)


class MilestoneCreate(MilestoneBase):
    pass


class MilestoneUpdate(BaseModel):
    title: Optional[str] = Field(default=None, min_length=1, max_length=120)
    description: Optional[str] = None
    target_level: Optional[int] = Field(default=None, ge=2, le=20)
    is_completed: Optional[bool] = None


class MilestoneOut(MilestoneBase):
    id: uuid.UUID
    campaign_id: uuid.UUID
    xp_granted: int = 0
    is_completed: bool
    completed_at: Optional[datetime] = None
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


# --- Characters ---
class CharacterBase(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    race: str
    subrace: Optional[str] = None
    class_slug: str
    level: int = Field(default=1, ge=1, le=20)
    experience: int = Field(default=0, ge=0)
    avatar_url: Optional[str] = None
    status: str = "alive"
    status_note: str = ""
    sheet: dict[str, Any] = {}

class CharacterOut(CharacterBase):
    id: uuid.UUID
    owner_id: Optional[uuid.UUID] = None
    campaign_id: Optional[uuid.UUID] = None
    version: int
    created_at: datetime
    updated_at: datetime
    model_config = ConfigDict(from_attributes=True)

class CharacterCreationChoices(BaseModel):
    """Elecciones de nivel 1; las cifras finales se calculan en el servidor."""
    base_stats: dict[str, int]
    racial_abilities: list[str] = Field(default_factory=list)
    class_skills: list[str] = Field(default_factory=list)
    race_skills: list[str] = Field(default_factory=list)
    background_id: str
    replacement_skills: list[str] = Field(default_factory=list)
    expertise: list[str] = Field(default_factory=list)

    @field_validator("base_stats", mode="before")
    @classmethod
    def strict_base_scores(cls, value):
        if not isinstance(value, dict) or any(type(score) is not int for score in value.values()):
            raise ValueError("Las puntuaciones base deben ser enteros.")
        return value


class CharacterCreate(CharacterBase):
    creation: CharacterCreationChoices


class LevelUpChoices(BaseModel):
    """Elecciones de subida de nivel según D&D 5e (2014)."""
    hp_roll: Optional[int] = None
    asi: dict[str, int] = Field(default_factory=dict)
    subclass: Optional[str] = Field(default=None, max_length=80)

    @field_validator("hp_roll", mode="before")
    @classmethod
    def strict_hp_roll(cls, value):
        if value is not None and type(value) is not int:
            raise ValueError("La tirada de dado de golpe debe ser un entero.")
        return value

    @field_validator("asi", mode="before")
    @classmethod
    def strict_asi_scores(cls, value):
        if not isinstance(value, dict) or any(type(v) is not int for v in value.values()):
            raise ValueError("Los incrementos de ASI deben ser enteros.")
        return value


class CharacterUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=80)
    avatar_url: Optional[str] = None
    sheet: Optional[dict[str, Any]] = None
    level: Optional[int] = Field(default=None, ge=1, le=20)
    experience: Optional[int] = Field(default=None, ge=0)
    level_up: Optional[LevelUpChoices] = None
    leave_campaign: bool = False
    version: int  # Required for optimistic locking


class AwardXpIn(BaseModel):
    xp: int = Field(gt=0, description="Cantidad de experiencia a otorgar al personaje")


class CharacterStatusUpdate(BaseModel):
    status: CharacterStatus
    status_note: Optional[str] = Field(default="", max_length=200)

class StatusEventOut(BaseModel):
    id: uuid.UUID
    character_id: uuid.UUID
    changed_by: uuid.UUID
    old_status: str
    new_status: str
    note: str
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)
