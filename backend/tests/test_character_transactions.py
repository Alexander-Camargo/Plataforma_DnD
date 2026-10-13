from app.db.models import Character
import uuid


def test_invalid_update_does_not_persist_earlier_field_changes(client, world, db):
    url = "/api/v1/characters/" + world["character"]["id"]
    response = client.patch(url, headers=world["player"]["headers"], json={
        "version": 1, "name": "No debe guardarse", "level": 2,
        "sheet": {"stats": {"fue": 21}},
    })
    assert response.status_code == 400
    saved = client.get(url, headers=world["player"]["headers"]).json()
    assert saved["name"] == "Lina"
    assert saved["level"] == 1
    assert saved["version"] == 1
    assert saved["sheet"]["stats"]["fue"] == 14
    entity = db.get(Character, uuid.UUID(saved["id"]))
    assert entity.level == 1


def test_campaign_history_accumulates_without_losing_previous_entries(client, joined_world):
    world = joined_world
    url = "/api/v1/characters/" + world["character"]["id"]
    first = client.patch(url, headers=world["player"]["headers"], json={
        "version": world["character"]["version"], "leave_campaign": True,
    }).json()
    second_campaign = client.post("/api/v1/campaigns/", headers=world["master"]["headers"],
                                  json={"name": "Segunda aventura"}).json()
    joined = client.post("/api/v1/campaigns/join", headers=world["player"]["headers"], json={
        "join_code": second_campaign["join_code"], "character_id": first["id"],
    })
    assert joined.status_code == 200
    current = client.get(url, headers=world["player"]["headers"]).json()
    finished = client.patch(url, headers=world["player"]["headers"], json={
        "version": current["version"], "leave_campaign": True,
    }).json()
    assert [entry["name"] for entry in finished["sheet"]["campaign_history"]] == [
        "La frontera", "Segunda aventura",
    ]
    assert finished["sheet"]["hp"] == 12

