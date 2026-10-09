"""Hash de contraseñas, cifrado de datos personales y tokens JWT."""
import hashlib
import hmac
from datetime import datetime, timedelta, timezone
from typing import Literal

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerificationError
from cryptography.fernet import Fernet, InvalidToken

from app.core.config import get_settings

settings = get_settings()

_hasher = PasswordHasher()  # Argon2id con parámetros recomendados
_fernet = Fernet(settings.data_encryption_key.encode())

TokenType = Literal["access", "refresh"]


# ---------- Contraseñas ----------
def hash_password(password: str) -> str:
    return _hasher.hash(password)


def verify_password(password_hash: str, password: str) -> bool:
    try:
        return _hasher.verify(password_hash, password)
    except VerificationError:
        return False


# ---------- Cifrado de datos personales (email) ----------
def encrypt(value: str) -> str:
    return _fernet.encrypt(value.encode()).decode()


def decrypt(token: str) -> str:
    try:
        return _fernet.decrypt(token.encode()).decode()
    except InvalidToken:
        return ""


def blind_index(value: str) -> str:
    """HMAC determinista: permite unicidad y búsqueda sin guardar el valor en claro."""
    normalized = value.strip().lower().encode()
    return hmac.new(settings.email_hash_key.encode(), normalized, hashlib.sha256).hexdigest()


# ---------- JWT ----------
def create_token(user_id: str, token_version: int, kind: TokenType) -> str:
    now = datetime.now(timezone.utc)
    ttl = (
        timedelta(minutes=settings.access_token_minutes)
        if kind == "access"
        else timedelta(days=settings.refresh_token_days)
    )
    payload = {"sub": user_id, "tv": token_version, "type": kind, "iat": now, "exp": now + ttl}
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_token(token: str, expected: TokenType) -> dict | None:
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    except jwt.PyJWTError:
        return None
    if payload.get("type") != expected:
        return None
    return payload
