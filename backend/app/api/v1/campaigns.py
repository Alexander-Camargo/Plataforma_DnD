import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_current_user
from app.schemas.api_models import CampaignCreate, CampaignOut, CampaignJoin, CampaignUpdate
from app.db.models import User, Campaign, CampaignMember, Character
from app.services.auth_service import generate_join_code

router = APIRouter()


def _serialize(campaign: Campaign, user: User) -> CampaignOut:
    """Las notas ocultas solo las ve el DM."""
    out = CampaignOut.model_validate(campaign)
    if campaign.dm_id != user.id:
        out.dm_notes = ""
    return out


def _get_member_campaign(db: Session, campaign_id: uuid.UUID, user: User) -> Campaign:
    campaign = db.query(Campaign).filter(Campaign.id == campaign_id).first()
    if not campaign:
        raise HTTPException(status_code=404, detail="Campaña no encontrada")
    is_member = db.query(CampaignMember).filter_by(
        campaign_id=campaign.id, user_id=user.id
    ).first()
    if not is_member:
        raise HTTPException(status_code=403, detail="No perteneces a esta campaña")
    return campaign


@router.post("/", response_model=CampaignOut, status_code=201)
def create_campaign(
    campaign_in: CampaignCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Generar código único
    for _ in range(10):
        code = generate_join_code()
        if not db.query(Campaign).filter(Campaign.join_code == code).first():
            break
    else:
        raise HTTPException(status_code=500, detail="No se pudo generar un código único")

    campaign = Campaign(
        name=campaign_in.name.strip(),
        description=campaign_in.description or "",
        dm_id=current_user.id,
        join_code=code
    )
    db.add(campaign)
    db.flush()

    # El DM es miembro automáticamente (misma transacción)
    db.add(CampaignMember(campaign_id=campaign.id, user_id=current_user.id, role="dm"))
    db.commit()
    db.refresh(campaign)

    return _serialize(campaign, current_user)


@router.post("/join", response_model=CampaignOut)
def join_campaign(
    join_in: CampaignJoin,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Une al usuario a la campaña con uno de sus personajes (un personaje, una campaña activa)."""
    campaign = db.query(Campaign).filter(
        Campaign.join_code == join_in.join_code.strip().upper()
    ).first()
    if not campaign:
        raise HTTPException(status_code=404, detail="Código de campaña inválido")

    if campaign.dm_id == current_user.id:
        raise HTTPException(status_code=400, detail="Eres el DM de esta campaña")

    char = db.query(Character).filter(
        Character.id == join_in.character_id, Character.owner_id == current_user.id
    ).first()
    if not char:
        raise HTTPException(status_code=404, detail="Personaje no encontrado")
    if char.campaign_id is not None:
        raise HTTPException(
            status_code=400,
            detail="Ese personaje ya está en una campaña activa. Debe terminarla primero.",
        )

    member = db.query(CampaignMember).filter_by(
        campaign_id=campaign.id, user_id=current_user.id
    ).first()
    if not member:
        db.add(CampaignMember(campaign_id=campaign.id, user_id=current_user.id, role="player"))

    char.campaign_id = campaign.id
    char.version += 1
    db.commit()
    db.refresh(campaign)
    return _serialize(campaign, current_user)


@router.get("/", response_model=list[CampaignOut])
def list_my_campaigns(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Campañas donde el usuario es miembro (incluyendo las que es DM)
    campaigns = db.query(Campaign).join(CampaignMember).filter(
        CampaignMember.user_id == current_user.id
    ).order_by(Campaign.created_at.desc()).all()
    return [_serialize(c, current_user) for c in campaigns]


@router.get("/{campaign_id}", response_model=CampaignOut)
def get_campaign(
    campaign_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return _serialize(_get_member_campaign(db, campaign_id, current_user), current_user)


@router.patch("/{campaign_id}", response_model=CampaignOut)
def update_campaign(
    campaign_id: uuid.UUID,
    campaign_in: CampaignUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    campaign = db.query(Campaign).filter(Campaign.id == campaign_id).first()
    if not campaign:
        raise HTTPException(status_code=404, detail="Campaña no encontrada")

    if campaign.dm_id != current_user.id:
        raise HTTPException(status_code=403, detail="No tienes permiso, solo el DM puede editar")

    if campaign_in.name is not None:
        campaign.name = campaign_in.name.strip()
    if campaign_in.description is not None:
        campaign.description = campaign_in.description
    if campaign_in.dm_notes is not None:
        campaign.dm_notes = campaign_in.dm_notes

    db.commit()
    db.refresh(campaign)
    return _serialize(campaign, current_user)
