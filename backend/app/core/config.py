"""Configuración central leída de variables de entorno (.env)."""
from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    env: str = "development"
    database_url: str = "sqlite:///./dev.db"

    # Seguridad
    jwt_secret: str = "change-me-in-production-please-32b"
    jwt_algorithm: str = "HS256"
    access_token_minutes: int = 30
    refresh_token_days: int = 14
    # Clave Fernet (base64 urlsafe de 32 bytes) para cifrar datos personales.
    data_encryption_key: str = "u0Zr0L5mJ0sQ8Xc1w2bq0m2zq7Y1kQ9C8vR3n4S5t6A="
    # Clave para el hash ciego (HMAC) del email, permite buscar sin descifrar.
    email_hash_key: str = "change-me-email-pepper"

    # Media (imágenes) - carpeta montada desde el host
    media_root: Path = Path("./media")
    media_url: str = "/media"
    max_upload_mb: int = 5

    # Solo se usa en desarrollo (en producción la web va por el mismo origen)
    cors_origins: list[str] = ["*"]

    @property
    def is_production(self) -> bool:
        return self.env == "production"


@lru_cache
def get_settings() -> Settings:
    return Settings()
