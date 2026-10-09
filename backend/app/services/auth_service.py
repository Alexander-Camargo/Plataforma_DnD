"""Servicios de autenticación."""
import string
import secrets
from typing import Optional
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from app.db.models import User
from app.core.security import hash_password, verify_password, encrypt, blind_index, create_token
from app.schemas.api_models import UserCreate, UserLogin, Token


def create_user(db: Session, user_in: UserCreate) -> User:
    email_hash = blind_index(user_in.email)
    
    # Check if exists
    if db.query(User).filter(User.email_hash == email_hash).first():
        raise HTTPException(status_code=400, detail="El correo ya está registrado")
    
    username_norm = user_in.username.strip().lower()
    if db.query(User).filter(User.username_norm == username_norm).first():
        raise HTTPException(status_code=400, detail="El nombre de usuario ya está en uso")

    db_user = User(
        username=user_in.username.strip(),
        username_norm=username_norm,
        email_encrypted=encrypt(user_in.email.strip().lower()),
        email_hash=email_hash,
        password_hash=hash_password(user_in.password)
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user


def authenticate_user(db: Session, user_in: UserLogin) -> Optional[User]:
    identifier = user_in.identifier.strip()
    if "@" in identifier:
        user = db.query(User).filter(User.email_hash == blind_index(identifier)).first()
    else:
        user = db.query(User).filter(User.username_norm == identifier.lower()).first()
    if not user:
        return None
    if not verify_password(user.password_hash, user_in.password):
        return None
    return user


def login(db: Session, user_in: UserLogin) -> Token:
    user = authenticate_user(db, user_in)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario/correo o contraseña incorrectos",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    access_token = create_token(str(user.id), user.token_version, "access")
    refresh_token = create_token(str(user.id), user.token_version, "refresh")
    
    return Token(access_token=access_token, refresh_token=refresh_token)

def generate_join_code(length: int = 8) -> str:
    alphabet = string.ascii_uppercase + string.digits
    return ''.join(secrets.choice(alphabet) for i in range(length))
