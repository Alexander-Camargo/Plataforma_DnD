"""
Archivo: test_characters_api.py
Propósito: Pruebas de integración para los endpoints de personajes (propiedad, permisos de campaña, bloqueo optimista, subida de nivel 5e, estados del DM y eliminación).
Creador: Joshua Pérez Bullen / Alexander Camargo
Modificaciones / Actualizaciones:
- 2026-10-12 [Joshua Pérez Bullen]: Pruebas de permisos, bloqueo optimista, validación de estadísticas y eventos de estado del DM.
- 2026-10-18 [Alexander Camargo]: Pruebas de integración para subida de nivel 5e (PG, subclase, ASI y desbloqueo de rasgos).
"""
import uuid
import pytest
from sqlalchemy import select
from app.db.models import Character, StatusEvent

PREFIX = "/api/v1/characters"


def test_create_defaults_ownership_and_private_listing(client, world):
    char = world["character"]
    assert char["owner_id"] == str(world["player"]["user"].id)
    assert char["status"] == "alive"
    assert char["version"] == 1
    assert char["sheet"]["hp"] == 12
    assert client.get(PREFIX + "/me", headers=world["player"]["headers"]).json()[0]["id"] == char["id"]
    assert client.get(PREFIX + "/me", headers=world["outsider"]["headers"]).json() == []


def test_private_character_is_not_visible_to_outsider(client, world):
    assert client.get(PREFIX + "/" + world["character"]["id"],
                      headers=world["outsider"]["headers"]).status_code == 403


def test_members_can_read_but_only_owner_edits(client, joined_world):
    world = joined_world
    url = PREFIX + "/" + world["character"]["id"]
    assert client.get(url, headers=world["master"]["headers"]).status_code == 200
    assert client.get(PREFIX + "/", params={"campaign_id": world["campaign"]["id"]},
                      headers=world["master"]["headers"]).status_code == 200
    assert client.get(PREFIX + "/", params={"campaign_id": world["campaign"]["id"]},
                      headers=world["outsider"]["headers"]).status_code == 403
    for actor in ("master", "outsider"):
        assert client.patch(url, headers=world[actor]["headers"],
                            json={"version": world["character"]["version"], "name": "No"}).status_code == 403


def test_update_increments_version_and_rejects_stale_write(client, world):
    url = PREFIX + "/" + world["character"]["id"]
    response = client.patch(url, headers=world["player"]["headers"], json={
        "version": 1, "name": " Lina nueva ", "avatar_url": "https://example.com/hero.png",
        "sheet": {"stats": {"fue": 15}, "equipment": ["Cuerda"]}})
    assert response.status_code == 200
    assert response.json()["version"] == 2
    assert response.json()["name"] == "Lina nueva"
    assert response.json()["sheet"]["equipment"] == ["Cuerda"]
    assert client.patch(url, headers=world["player"]["headers"],
                        json={"version": 1, "name": "Sobrescrito"}).status_code == 409
    assert client.get(url, headers=world["player"]["headers"]).json()["name"] == "Lina nueva"


def test_character_without_campaign_cannot_level_up(client, world):
    url = PREFIX + "/" + world["character"]["id"]
    response = client.patch(url, headers=world["player"]["headers"], json={"version": 1, "level": 2})
    assert response.status_code == 400
    assert "campaña activa" in response.json()["detail"]


@pytest.mark.parametrize("level,status", [(1,200),(3,400),(0,422),(21,422)])
def test_level_update_validation(client, world, level, status):
    response = client.patch(PREFIX + "/" + world["character"]["id"],
                            headers=world["player"]["headers"], json={"version": 1, "level": level})
    assert response.status_code == status
    if status == 200:
        assert response.json()["level"] == level


def test_level_up_progression_with_milestones_xp_and_features(client, joined_world):
    world = joined_world
    char = world["character"]
    url = PREFIX + "/" + char["id"]
    p_headers = world["player"]["headers"]
    m_headers = world["master"]["headers"]
    c_id = world["campaign"]["id"]

    # 1. Sin XP suficiente (0 XP), no puede subir a nivel 2
    r_bad = client.patch(url, headers=p_headers, json={"version": char["version"], "level": 2})
    assert r_bad.status_code == 400
    assert "requiere 300 XP" in r_bad.json()["detail"]

    # 2. El DM crea un Hito para nivel 2 y lo marca completado
    m_res = client.post(f"/api/v1/campaigns/{c_id}/milestones", headers=m_headers, json={
        "title": "Derrotar a los bandidos de la cueva",
        "target_level": 2
    })
    assert m_res.status_code == 201
    milestone = m_res.json()
    assert milestone["target_level"] == 2
    assert milestone["xp_granted"] == 300

    # Completar hito -> otorga automáticamente 300 XP a los personajes de la campaña
    c_res = client.patch(f"/api/v1/campaigns/{c_id}/milestones/{milestone['id']}", headers=m_headers, json={
        "is_completed": True
    })
    assert c_res.status_code == 200
    assert c_res.json()["is_completed"] is True

    # Verificar que el personaje recibió 300 XP
    updated_char = client.get(url, headers=p_headers).json()
    assert updated_char["experience"] == 300

    # 3. Ahora sí puede subir a Nivel 2 con tirada manual de 8
    r2 = client.patch(url, headers=p_headers, json={
        "version": updated_char["version"], "level": 2, "level_up": {"hp_roll": 8}
    })
    assert r2.status_code == 200
    c2 = r2.json()
    assert c2["level"] == 2
    assert c2["sheet"]["hp"] == 22
    assert any(f["name"] == "Acción súbita" for f in c2["sheet"]["features"])

    # 4. El DM otorga XP directamente para llegar a nivel 3 (requiere 900 XP; tiene 300 -> sumamos 600)
    award_res = client.post(f"{url}/award-xp", headers=m_headers, json={"xp": 600})
    assert award_res.status_code == 200
    assert award_res.json()["experience"] == 900

    # 5. Nivel 2 -> 3 con elección de Arquetipo Marcial y media fija (6 + 2 = +8 -> 30 PG)
    r3 = client.patch(url, headers=p_headers, json={
        "version": award_res.json()["version"], "level": 3, "level_up": {"subclass": "Maestro de Batalla"}
    })
    assert r3.status_code == 200
    c3 = r3.json()
    assert c3["level"] == 3
    assert c3["sheet"]["hp"] == 30
    assert c3["sheet"]["subclass"] == "Maestro de Batalla"

    # 6. Sumar XP para nivel 4 (requiere 2700 XP; tiene 900 -> sumamos 1800)
    c4_xp = client.post(f"{url}/award-xp", headers=m_headers, json={"xp": 1800}).json()
    assert c4_xp["experience"] == 2700

    # Nivel 3 -> 4 con ASI (+2 FUE -> 16) y media fija (+8 -> 38 PG)
    r4 = client.patch(url, headers=p_headers, json={
        "version": c4_xp["version"], "level": 4, "level_up": {"asi": {"fue": 2}}
    })
    assert r4.status_code == 200
    c4 = r4.json()
    assert c4["level"] == 4
    assert c4["sheet"]["stats"]["fue"] == 16
    assert c4["sheet"]["save_bonuses"]["fue"] == 5
    assert c4["sheet"]["hp"] == 38



@pytest.mark.parametrize("score", [0,21,1.5,"14",True])
def test_invalid_stats_are_rejected_without_persistence(client, world, score):
    url = PREFIX + "/" + world["character"]["id"]
    response = client.patch(url, headers=world["player"]["headers"],
                            json={"version": 1, "sheet": {"stats": {"fue": score}}})
    assert response.status_code == 400
    saved = client.get(url, headers=world["player"]["headers"]).json()
    assert saved["version"] == 1
    assert saved["sheet"]["stats"]["fue"] == 14


def test_leaving_archives_campaign_and_preserves_sheet(client, joined_world):
    world = joined_world
    response = client.patch(PREFIX + "/" + world["character"]["id"],
                            headers=world["player"]["headers"],
                            json={"version": world["character"]["version"], "leave_campaign": True})
    assert response.status_code == 200
    char = response.json()
    assert char["campaign_id"] is None
    assert char["sheet"]["hp"] == 12
    history = char["sheet"]["campaign_history"]
    assert len(history) == 1
    assert history[0]["id"] == world["campaign"]["id"]
    assert history[0]["name"] == world["campaign"]["name"]
    assert history[0]["final_status"] == "alive"
    assert history[0]["finished_at"]
    second = client.patch(PREFIX + "/" + char["id"], headers=world["player"]["headers"],
                          json={"version": char["version"], "leave_campaign": True})
    assert len(second.json()["sheet"]["campaign_history"]) == 1


@pytest.mark.parametrize("actor,status", [("master",200),("player",403),("outsider",403)])
def test_only_dm_changes_status_and_records_event(client, joined_world, db, actor, status):
    world = joined_world
    char = world["character"]
    response = client.patch(PREFIX + "/" + char["id"] + "/status",
                            headers=world[actor]["headers"], json={"status": "lost", "status_note": "Portal"})
    assert response.status_code == status
    events = db.scalars(select(StatusEvent)).all()
    if status == 200:
        assert response.json()["version"] == char["version"] + 1
        assert len(events) == 1
        assert events[0].old_status == "alive"
        assert events[0].new_status == "lost"
        assert events[0].note == "Portal"
        assert events[0].changed_by == world["master"]["user"].id
    else:
        assert not events


def test_free_character_cannot_receive_dm_status(client, world):
    assert client.patch(PREFIX + "/" + world["character"]["id"] + "/status",
                        headers=world["master"]["headers"], json={"status": "dead"}).status_code == 400


def test_delete_owner_and_active_campaign_guards(client, joined_world, db):
    world = joined_world
    char = world["character"]
    url = PREFIX + "/" + char["id"]
    assert client.delete(url, headers=world["outsider"]["headers"]).status_code == 403
    assert client.delete(url, headers=world["player"]["headers"]).status_code == 409
    changed = client.patch(url + "/status", headers=world["master"]["headers"], json={"status": "lost"}).json()
    left = client.patch(url, headers=world["player"]["headers"],
                        json={"version": changed["version"], "leave_campaign": True})
    assert left.status_code == 200
    response = client.delete(url, headers=world["player"]["headers"])
    assert response.status_code == 204
    assert response.content == b""
    assert db.get(Character, uuid.UUID(char["id"])) is None
    assert db.scalars(select(StatusEvent)).all() == []
    assert client.get(url, headers=world["player"]["headers"]).status_code == 404


@pytest.mark.parametrize("method", ["get","patch","delete","status"])
def test_missing_character(client, actors, method):
    url = PREFIX + "/" + str(uuid.uuid4())
    kwargs = {}
    if method == "patch":
        kwargs["json"] = {"version": 1}
    if method == "status":
        url += "/status"
        method = "patch"
        kwargs["json"] = {"status": "alive"}
    assert getattr(client, method)(url, headers=actors["player"]["headers"], **kwargs).status_code == 404


@pytest.mark.parametrize("path", ["/api/v1/characters/me", "/api/v1/campaigns/"])
def test_protected_routes_require_auth(client, path):
    assert client.get(path).status_code == 401


