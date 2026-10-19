import copy
import pytest
from tests.test_creation_rules import selection


def payload(race='human', cls='fighter', subrace=None):
    return {'name': 'Reglas', 'race': race, 'class_slug': cls, 'subrace': subrace,
            'creation': selection(race, cls, subrace)[4]}


def test_catalog_requires_authentication_and_exposes_choices(client, actors):
    assert client.get('/api/v1/rules/creation').status_code == 401
    response = client.get('/api/v1/rules/creation', headers=actors['player']['headers'])
    assert response.status_code == 200
    data = response.json()
    assert data['edition'] == '5e-2014'
    assert len(data['skills']) == 18 and len(data['classes']) == 12
    elf = next(r for r in data['races'] if r['id'] == 'half_elf')
    assert elf['bonus_count'] == 2 and 'car' not in elf['bonus_options']


def test_catalog_tables_are_seeded_and_queried_from_db(client, actors, db):
    from app.db.models import DndBackground, DndClass, DndRace, DndRuleConfig, DndSkill, DndSubrace

    assert db.query(DndRace).count() == 9
    assert db.query(DndSubrace).count() == 8
    assert db.query(DndClass).count() == 12
    assert db.query(DndBackground).count() == 13
    assert db.query(DndSkill).count() == 18
    assert db.query(DndRuleConfig).count() == 11

    human = db.get(DndRace, 'human')
    human.speed = 35
    db.commit()

    response = client.get('/api/v1/rules/creation', headers=actors['player']['headers'])
    assert response.status_code == 200
    races = {r['id']: r for r in response.json()['races']}
    assert races['human']['speed'] == 35


def test_server_replaces_forged_calculations(client, actors):
    body = payload()
    body['sheet'] = {'stats': {'fue': 99}, 'hp': 999, 'skill_bonuses': {'atletismo': 99},
                     'background': {'history': 'Recuerdo'}}
    response = client.post('/api/v1/characters/', json=body, headers=actors['player']['headers'])
    assert response.status_code == 201
    sheet = response.json()['sheet']
    assert sheet['stats']['fue'] == 14 and sheet['hp'] == 12
    assert sheet['save_bonuses']['fue'] == 4
    assert sheet['background']['history'] == 'Recuerdo'
    assert len(sheet['skill_bonuses']) == 18


@pytest.mark.parametrize('race,subrace', [('dwarf', 'hill_dwarf'), ('elf', 'wood_elf'), ('half_elf', None)])
def test_api_applies_racial_choices(client, actors, race, subrace):
    response = client.post('/api/v1/characters/', json=payload(race, subrace=subrace), headers=actors['player']['headers'])
    assert response.status_code == 201
    sheet = response.json()['sheet']
    if race == 'dwarf': assert sheet['hp'] == 13
    if race == 'elf': assert sheet['speed'] == 35 and sheet['skills']['percepcion']
    if race == 'half_elf': assert sheet['stats']['car'] == 10 and sheet['stats']['fue'] == 14


@pytest.mark.parametrize('change,status', [({'subrace': 'hill_dwarf'}, 400), ({'level': 2}, 400),
                                        ({'creation': None}, 422)])
def test_api_rejects_invalid_creation(client, actors, change, status):
    body = payload(); body.update(change)
    assert client.post('/api/v1/characters/', json=body, headers=actors['player']['headers']).status_code == status


def test_api_rejects_boolean_and_over_budget_scores(client, actors):
    body = payload()
    body['creation']['base_stats']['fue'] = True
    assert client.post('/api/v1/characters/', json=body, headers=actors['player']['headers']).status_code == 422
    body = payload()
    body['creation']['base_stats'] = {key: 15 for key in body['creation']['base_stats']}
    assert client.post('/api/v1/characters/', json=body, headers=actors['player']['headers']).status_code == 400
