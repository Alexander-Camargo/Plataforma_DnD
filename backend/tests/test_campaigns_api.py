"""
Archivo: test_campaigns_api.py
Propósito: Pruebas de integración de la API de campañas (creación, unirse, notas del DM y gestión de hitos/milestones).
Creador: Joshua Pérez Bullen / Alexander Camargo
Modificaciones / Actualizaciones:
- 2026-10-12 [Joshua Pérez Bullen]: Pruebas de membresía, códigos de unión, roles DM y aislamiento de notas.
- 2026-10-18 [Alexander Camargo]: Pruebas de integración para hitos de campaña (creación, edición, eliminación y permisos).
"""
from tests.test_creation_rules import selection
import uuid
import pytest
from sqlalchemy import select
from app.db.models import CampaignMember, Character
from app.api.v1 import campaigns

PREFIX = "/api/v1/campaigns"


def test_create_campaign_makes_dm_member(client, world, db):
    campaign = world["campaign"]
    member = db.get(CampaignMember, (uuid.UUID(campaign["id"]), world["master"]["user"].id))
    assert member.role == "dm"
    assert len(campaign["join_code"]) == 8
    listing = client.get(PREFIX + "/", headers=world["master"]["headers"]).json()
    assert [item["id"] for item in listing] == [campaign["id"]]
    assert client.get(PREFIX + "/", headers=world["outsider"]["headers"]).json() == []


def test_join_normalizes_code_and_links_character(client, world, db):
    response = client.post(PREFIX + "/join", headers=world["player"]["headers"], json={
        "join_code": " " + world["campaign"]["join_code"].lower() + " ",
        "character_id": world["character"]["id"]})
    assert response.status_code == 200
    char = db.get(Character, uuid.UUID(world["character"]["id"]))
    db.refresh(char)
    assert str(char.campaign_id) == world["campaign"]["id"]
    assert char.version == world["character"]["version"] + 1


@pytest.mark.parametrize("actor", ["player", "outsider"])
def test_only_dm_edits_campaign(client, world, actor):
    response = client.patch(PREFIX + "/" + world["campaign"]["id"],
                            headers=world[actor]["headers"], json={"dm_notes": "Secreto"})
    assert response.status_code == 403


def test_hidden_notes_only_reach_dm(client, joined_world):
    world = joined_world
    url = PREFIX + "/" + world["campaign"]["id"]
    assert client.patch(url, headers=world["master"]["headers"], json={
        "name": "Nuevo título", "description": "Nueva descripción", "dm_notes": "La pista secreta"}).status_code == 200
    assert client.get(url, headers=world["master"]["headers"]).json()["dm_notes"] == "La pista secreta"
    assert client.get(url, headers=world["player"]["headers"]).json()["dm_notes"] == ""
    assert client.get(PREFIX + "/", headers=world["player"]["headers"]).json()[0]["dm_notes"] == ""
    assert client.get(url, headers=world["outsider"]["headers"]).status_code == 403


def test_invalid_join_code(client, world):
    assert client.post(PREFIX + "/join", headers=world["player"]["headers"], json={
        "join_code": "INVALID", "character_id": world["character"]["id"]}).status_code == 404


def test_dm_cannot_join_own_campaign(client, world):
    assert client.post(PREFIX + "/join", headers=world["master"]["headers"], json={
        "join_code": world["campaign"]["join_code"],
        "character_id": world["character"]["id"]}).status_code == 400


def test_cannot_join_with_another_users_character(client, world):
    assert client.post(PREFIX + "/join", headers=world["outsider"]["headers"], json={
        "join_code": world["campaign"]["join_code"],
        "character_id": world["character"]["id"]}).status_code == 404


def test_active_character_cannot_join_again(client, joined_world):
    world = joined_world
    assert client.post(PREFIX + "/join", headers=world["player"]["headers"], json={
        "join_code": world["campaign"]["join_code"],
        "character_id": world["character"]["id"]}).status_code == 400


def test_multiple_characters_do_not_duplicate_membership(client, joined_world, db):
    world = joined_world
    second = client.post("/api/v1/characters/", headers=world["player"]["headers"],
                         json={"name": "Otro", "race": "Humano", "class_slug": "mago", "creation": selection(class_name="wizard")[4]}).json()
    assert client.post(PREFIX + "/join", headers=world["player"]["headers"], json={
        "join_code": world["campaign"]["join_code"], "character_id": second["id"]}).status_code == 200
    members = db.scalars(select(CampaignMember).where(
        CampaignMember.campaign_id == uuid.UUID(world["campaign"]["id"]),
        CampaignMember.user_id == world["player"]["user"].id)).all()
    assert len(members) == 1


@pytest.mark.parametrize("method", ["get", "patch"])
def test_missing_campaign(client, actors, method):
    request = getattr(client, method)
    kwargs = {"json": {"dm_notes": "Nota"}} if method == "patch" else {}
    assert request(PREFIX + "/" + str(uuid.uuid4()), headers=actors["master"]["headers"], **kwargs).status_code == 404


def test_join_code_collision_retries(client, world, monkeypatch):
    codes = iter([world["campaign"]["join_code"], "NEWCODE1"])
    monkeypatch.setattr(campaigns, "generate_join_code", lambda: next(codes))
    response = client.post(PREFIX + "/", headers=world["master"]["headers"], json={"name": "Nueva"})
    assert response.status_code == 201
    assert response.json()["join_code"] == "NEWCODE1"


def test_exhausted_join_codes_fail_safely(client, world, monkeypatch):
    monkeypatch.setattr(campaigns, "generate_join_code", lambda: world["campaign"]["join_code"])
    assert client.post(PREFIX + "/", headers=world["master"]["headers"],
                       json={"name": "Nueva"}).status_code == 500


def test_milestone_crud_and_permissions(client, joined_world):
    world = joined_world
    c_id = world["campaign"]["id"]
    m_headers = world["master"]["headers"]
    p_headers = world["player"]["headers"]
    o_headers = world["outsider"]["headers"]

    # 1. Outsider no puede ver ni crear hitos
    assert client.get(f"{PREFIX}/{c_id}/milestones", headers=o_headers).status_code == 403
    assert client.post(f"{PREFIX}/{c_id}/milestones", headers=o_headers, json={"title": "Hito 1", "target_level": 2}).status_code == 403

    # 2. Jugador puede ver pero no crear ni editar
    assert client.get(f"{PREFIX}/{c_id}/milestones", headers=p_headers).status_code == 200
    assert client.post(f"{PREFIX}/{c_id}/milestones", headers=p_headers, json={"title": "Hito 1", "target_level": 2}).status_code == 403

    # 3. DM crea un hito
    create_res = client.post(f"{PREFIX}/{c_id}/milestones", headers=m_headers, json={
        "title": "Salvar al herrero",
        "description": "Rescate en las minas",
        "target_level": 2
    })
    assert create_res.status_code == 201
    m = create_res.json()
    assert m["title"] == "Salvar al herrero"
    assert m["target_level"] == 2
    assert m["xp_granted"] == 300
    assert m["is_completed"] is False

    # 4. Listar hitos
    list_res = client.get(f"{PREFIX}/{c_id}/milestones", headers=p_headers)
    assert len(list_res.json()) == 1

    # 5. DM actualiza descripción
    patch_res = client.patch(f"{PREFIX}/{c_id}/milestones/{m['id']}", headers=m_headers, json={
        "description": "Nueva descripción"
    })
    assert patch_res.status_code == 200
    assert patch_res.json()["description"] == "Nueva descripción"

    # 6. DM elimina el hito
    assert client.delete(f"{PREFIX}/{c_id}/milestones/{m['id']}", headers=p_headers).status_code == 403
    assert client.delete(f"{PREFIX}/{c_id}/milestones/{m['id']}", headers=m_headers).status_code == 204
    assert len(client.get(f"{PREFIX}/{c_id}/milestones", headers=m_headers).json()) == 0


