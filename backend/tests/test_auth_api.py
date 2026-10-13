import uuid
import pytest
from sqlalchemy import select
from app.db.models import User
from app.core.security import create_token, decrypt

PREFIX = "/api/v1/auth"


def test_register_encrypts_email_and_does_not_expose_secrets(client, db):
    response = client.post(PREFIX + "/register", json={
        "username": "Adventurer", "email": "hero@example.com", "password": "Password123!"})
    assert response.status_code == 201
    assert set(response.json()) == {"id", "username", "created_at"}
    user = db.scalar(select(User).where(User.username_norm == "adventurer"))
    assert user.password_hash != "Password123!"
    assert user.email_encrypted != "hero@example.com"
    assert decrypt(user.email_encrypted) == "hero@example.com"


@pytest.mark.parametrize("changes", [
    {"username": "MASTER", "email": "new@example.com"},
    {"username": "new_player", "email": "MASTER@example.com"},
])
def test_duplicate_username_or_email_is_rejected(client, actors, changes):
    response = client.post(PREFIX + "/register", json={**changes, "password": "Password123!"})
    assert response.status_code == 400


@pytest.mark.parametrize("identifier", ["player", "PLAYER", " player ", "PLAYER@example.com"])
def test_login_by_username_or_email(client, actors, identifier):
    response = client.post(PREFIX + "/login", json={"identifier": identifier, "password": "Password123!"})
    assert response.status_code == 200
    tokens = response.json()
    me = client.get(PREFIX + "/me", headers={"Authorization": "Bearer " + tokens["access_token"]})
    assert me.status_code == 200
    assert me.json()["id"] == str(actors["player"]["user"].id)


@pytest.mark.parametrize("identifier,password", [("unknown","Password123!"),("player","wrong")])
def test_bad_credentials(client, actors, identifier, password):
    response = client.post(PREFIX + "/login", json={"identifier": identifier, "password": password})
    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"


@pytest.mark.parametrize("token_kind", ["missing", "invalid", "refresh", "revoked", "unknown", "bad-sub"])
def test_me_rejects_bad_sessions(client, actors, token_kind):
    user = actors["player"]["user"]
    headers = {}
    if token_kind != "missing":
        if token_kind == "invalid":
            token = "not-a-jwt"
        else:
            sub = "invalid-uuid" if token_kind == "bad-sub" else str(uuid.uuid4()) if token_kind == "unknown" else str(user.id)
            token = create_token(sub, 99 if token_kind == "revoked" else 0,
                                 "refresh" if token_kind == "refresh" else "access")
        headers = {"Authorization": "Bearer " + token}
    assert client.get(PREFIX + "/me", headers=headers).status_code == 401


def test_weak_registration_password_is_rejected(client):
    response = client.post(PREFIX + "/register", json={
        "username": "weak", "email": "weak@example.com", "password": "password"})
    assert response.status_code == 422

