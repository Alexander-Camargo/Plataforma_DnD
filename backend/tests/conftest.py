"""BD efímera por test: nunca usa la conexión de la aplicación local."""
import base64
import os
import uuid

# Se fijan antes de importar configuración, motor o criptografía.
os.environ["ENV"] = "test"
os.environ["DATABASE_URL"] = "sqlite://"
os.environ["DATA_ENCRYPTION_KEY"] = base64.urlsafe_b64encode(b"0" * 32).decode()
os.environ["JWT_SECRET"] = "test-only-secret-not-for-production-123456"
os.environ["EMAIL_HASH_KEY"] = "test-only-email-index"

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.main import app
from app.db.session import Base, get_db
from app.db.models import User
from app.core.security import hash_password, encrypt, blind_index, create_token


@pytest.fixture
def db():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)

    @event.listens_for(engine, "connect")
    def enable_foreign_keys(connection, _):
        connection.execute("PRAGMA foreign_keys=ON")

    Base.metadata.create_all(engine)
    with Session(engine, expire_on_commit=False) as session:
        yield session
    engine.dispose()


@pytest.fixture
def client(db):
    def override_db():
        with Session(db.get_bind(), expire_on_commit=False) as request_db:
            yield request_db
    app.dependency_overrides[get_db] = override_db
    # El lifespan también usa SQLite efímera; cada petición cierra su propia sesión.
    with TestClient(app, raise_server_exceptions=True) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture(scope="session")
def password_hash():
    return hash_password("Password123!")


@pytest.fixture
def actors(db, password_hash):
    result = {}
    for name in ("master", "player", "outsider"):
        user = User(id=uuid.uuid4(), username=name, username_norm=name,
                    email_encrypted=encrypt(f"{name}@example.com"),
                    email_hash=blind_index(f"{name}@example.com"),
                    password_hash=password_hash, token_version=0)
        db.add(user)
        db.commit()
        result[name] = {"user": user, "headers": {
            "Authorization": "Bearer " + create_token(str(user.id), 0, "access")}}
    return result


@pytest.fixture
def world(client, actors):
    campaign = client.post("/api/v1/campaigns/", headers=actors["master"]["headers"],
                           json={"name": "La frontera", "description": "Una aventura"}).json()
    character = client.post("/api/v1/characters/", headers=actors["player"]["headers"],
                            json={"name": "Lina", "race": "Humano", "class_slug": "guerrero",
                                  "sheet": {"stats": {"fue": 14, "con": 14}, "hp": 12}}).json()
    return {"campaign": campaign, "character": character, **actors}


@pytest.fixture
def joined_world(client, world):
    response = client.post("/api/v1/campaigns/join", headers=world["player"]["headers"],
                           json={"join_code": world["campaign"]["join_code"],
                                 "character_id": world["character"]["id"]})
    assert response.status_code == 200
    world["character"] = client.get("/api/v1/characters/" + world["character"]["id"],
                                   headers=world["player"]["headers"]).json()
    return world

