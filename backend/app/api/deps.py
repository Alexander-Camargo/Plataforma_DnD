"""Dependencias de FastAPI (DB, Auth)."""
import uuid
from typing import Generator
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.db.models import User
from app.core.config import get_settings
from app.core.security import decode_token

settings = get_settings()
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

def get_current_user(
    db: Session = Depends(get_db), token: str = Depends(oauth2_scheme)
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="No se pudieron validar las credenciales",
        headers={"WWW-Authenticate": "Bearer"},
    )
    payload = decode_token(token, "access")
    if payload is None:
        raise credentials_exception
    
    user_id = payload.get("sub")
    if user_id is None:
        raise credentials_exception

    try:
        user_uuid = uuid.UUID(str(user_id))
    except ValueError:
        raise credentials_exception

    user = db.query(User).filter(User.id == user_uuid).first()
    if user is None:
        raise credentials_exception
        
    # Verificar que el token no haya sido revocado (token_version)
    if payload.get("tv") != user.token_version:
        raise credentials_exception
        
    return user
