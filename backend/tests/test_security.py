import uuid
import jwt
import pytest
from app.core import security
from app.schemas.api_models import UserCreate, CharacterUpdate, CharacterStatusUpdate
from pydantic import ValidationError


def test_password_hash_is_salted_and_verifies():
    first = security.hash_password("Password123!")
    second = security.hash_password("Password123!")
    assert first != second
    assert "Password123!" not in first
    assert security.verify_password(first, "Password123!")
    assert not security.verify_password(first, "WrongPassword123!")


def test_email_encryption_and_blind_index():
    ciphertext = security.encrypt("player@example.com")
    assert ciphertext != "player@example.com"
    assert security.decrypt(ciphertext) == "player@example.com"
    assert security.decrypt("invalid-token") == ""
    assert security.blind_index(" Player@Example.com ") == security.blind_index("player@example.com")
    assert security.blind_index("other@example.com") != security.blind_index("player@example.com")


@pytest.mark.parametrize("kind", ["access", "refresh"])
def test_token_payload_and_type(kind):
    user_id = str(uuid.uuid4())
    token = security.create_token(user_id, 3, kind)
    payload = security.decode_token(token, kind)
    assert payload["sub"] == user_id
    assert payload["tv"] == 3
    assert payload["exp"] > payload["iat"]
    assert security.decode_token(token, "refresh" if kind == "access" else "access") is None


def test_expired_or_forged_tokens_are_rejected(monkeypatch):
    monkeypatch.setattr(security.settings, "access_token_minutes", -1)
    token = security.create_token(str(uuid.uuid4()), 0, "access")
    assert security.decode_token(token, "access") is None
    forged = jwt.encode({"sub": str(uuid.uuid4()), "type": "access"},
                        "another-test-secret-1234567890123456", algorithm="HS256")
    assert security.decode_token(forged, "access") is None
    assert security.decode_token("not-a-jwt", "access") is None


@pytest.mark.parametrize("password", ["Ab1!", "password123!", "PASSWORD123!", "Password!!!", "Password123"])
def test_password_requirements(password):
    with pytest.raises(ValidationError):
        UserCreate(username="player", email="player@example.com", password=password)


@pytest.mark.parametrize("level", [0,21])
def test_update_level_bounds(level):
    with pytest.raises(ValidationError):
        CharacterUpdate(version=1, level=level)


def test_update_requires_version():
    with pytest.raises(ValidationError):
        CharacterUpdate(name="Lina")


@pytest.mark.parametrize("status", ["poisoned", "unknown", ""])
def test_narrative_status_rejects_unknown_values(status):
    with pytest.raises(ValidationError):
        CharacterStatusUpdate(status=status)


def test_status_note_length():
    with pytest.raises(ValidationError):
        CharacterStatusUpdate(status="lost", status_note="x" * 201)

