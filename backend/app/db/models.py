"""Modelos ORM.

Las columnas que se consultan/filtran son relacionales; la ficha del personaje
(listas modulares: rasgos, equipo, conjuros...) vive en `sheet` como JSON/JSONB.
"""
import uuid
from datetime import datetime, timezone

from sqlalchemy import JSON, DateTime, ForeignKey, Integer, String, Text, Uuid
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base

JsonType = JSON().with_variant(JSONB(), "postgresql")


def _now() -> datetime:
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    username: Mapped[str] = mapped_column(String(32))
    username_norm: Mapped[str] = mapped_column(String(32), unique=True, index=True)
    email_encrypted: Mapped[str] = mapped_column(Text)
    email_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    token_version: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class Campaign(Base):
    __tablename__ = "campaigns"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(80))
    description: Mapped[str] = mapped_column(Text, default="")
    dm_notes: Mapped[str] = mapped_column(Text, default="")  # Notas ocultas del Master
    board: Mapped[str] = mapped_column(Text, default="")  # Tablón de anuncios del DM
    join_code: Mapped[str] = mapped_column(String(8), unique=True, index=True)
    dm_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    dm: Mapped[User] = relationship()
    members: Mapped[list["CampaignMember"]] = relationship(
        back_populates="campaign", cascade="all, delete-orphan"
    )


class CampaignMember(Base):
    __tablename__ = "campaign_members"

    campaign_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("campaigns.id", ondelete="CASCADE"), primary_key=True
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    role: Mapped[str] = mapped_column(String(10))  # "dm" | "player"
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    campaign: Mapped[Campaign] = relationship(back_populates="members")
    user: Mapped[User] = relationship()


class Character(Base):
    __tablename__ = "characters"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    owner_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    campaign_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("campaigns.id", ondelete="SET NULL"), index=True, nullable=True
    )
    name: Mapped[str] = mapped_column(String(80))
    race: Mapped[str] = mapped_column(String(40))
    subrace: Mapped[str | None] = mapped_column(String(40), nullable=True)
    class_slug: Mapped[str] = mapped_column(String(40))
    level: Mapped[int] = mapped_column(Integer, default=1)
    avatar_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    # Estado narrativo: solo lo edita el DM de la campaña
    status: Mapped[str] = mapped_column(String(30), default="alive")
    status_note: Mapped[str] = mapped_column(String(200), default="")
    sheet: Mapped[dict] = mapped_column(JsonType, default=dict)
    version: Mapped[int] = mapped_column(Integer, default=1)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_now, onupdate=_now
    )

    owner: Mapped[User] = relationship()
    campaign: Mapped[Campaign | None] = relationship()


class StatusEvent(Base):
    """Crónica de cambios de estado hechos por el DM (visible para toda la mesa)."""

    __tablename__ = "status_events"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    campaign_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("campaigns.id", ondelete="CASCADE"), index=True
    )
    character_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("characters.id", ondelete="CASCADE")
    )
    changed_by: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    old_status: Mapped[str] = mapped_column(String(30))
    new_status: Mapped[str] = mapped_column(String(30))
    note: Mapped[str] = mapped_column(String(200), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    character: Mapped[Character] = relationship()
