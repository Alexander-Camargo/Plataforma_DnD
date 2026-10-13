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


@pytest.mark.parametrize("level,status", [(2,200),(1,200),(3,400),(0,422),(21,422)])
def test_level_update_validation(client, world, level, status):
    response = client.patch(PREFIX + "/" + world["character"]["id"],
                            headers=world["player"]["headers"], json={"version": 1, "level": level})
    assert response.status_code == status
    if status == 200:
        assert response.json()["level"] == level


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

