"""Esquemas Pydantic para la API."""
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


# --- Characters ---
class CharacterBase(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    race: str
    subrace: Optional[str] = None
    class_slug: str
    level: int = Field(default=1, ge=1, le=20)
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

class CharacterCreate(CharacterBase):
    pass

class CharacterUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=80)
    avatar_url: Optional[str] = None
    sheet: Optional[dict[str, Any]] = None
    level: Optional[int] = Field(default=None, ge=1, le=20)
    leave_campaign: bool = False
    version: int  # Required for optimistic locking

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
