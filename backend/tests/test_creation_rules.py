import copy
import pytest
from app.domain.rules import calculate_creation, calculate_check_bonus, refresh_derived_checks
from app.services.rules_catalog import creation_catalog, find_option


def selection(race_name="human", class_name="fighter", subrace_id=None):
    catalog = creation_catalog()
    race = find_option(catalog["races"], race_name, "Raza")
    cls = find_option(catalog["classes"], class_name, "Clase")
    subrace = next((item for item in race["subraces"] if item["id"] == subrace_id), None)
    choices = {"base_stats": {"fue": 13, "des": 12, "con": 13, "int": 10, "sab": 10, "car": 8},
               "racial_abilities": race["bonus_options"][:race["bonus_count"]],
               "class_skills": cls["skill_options"][:cls["skill_count"]],
               "race_skills": [item["key"] for item in catalog["skills"]][:race["skill_count"]],
               "background_id": "acolyte", "replacement_skills": [], "expertise": []}
    background = next(item for item in catalog["backgrounds"] if item["id"] == "acolyte")
    grants = [*race["fixed_skills"], *choices["class_skills"], *choices["race_skills"], *background["skills"]]
    available = [item["key"] for item in catalog["skills"] if item["key"] not in grants]
    choices["replacement_skills"] = available[:len(grants) - len(set(grants))]
    proficient = list(dict.fromkeys([*grants, *choices["replacement_skills"]]))
    choices["expertise"] = proficient[:cls["expertise_count"]]
    return catalog, race, cls, subrace, choices


@pytest.mark.parametrize("race,subrace,expected", [
    ("human", None, {"fue": 1,"des": 1,"con": 1,"int": 1,"sab": 1,"car": 1}),
    ("dwarf","hill_dwarf", {"con": 2,"sab": 1}),
    ("dwarf","mountain_dwarf", {"con": 2,"fue": 2}),
    ("elf","high_elf", {"des": 2,"int": 1}),
    ("elf","wood_elf", {"des": 2,"sab": 1}),
    ("halfling","lightfoot_halfling", {"des": 2,"car": 1}),
    ("halfling","stout_halfling", {"des": 2,"con": 1}),
    ("gnome","rock_gnome", {"int": 2,"con": 1}),
    ("gnome","forest_gnome", {"int": 2,"des": 1}),
    ("dragonborn",None, {"fue": 2,"car": 1}),
    ("half_orc",None, {"fue": 2,"con": 1}),
    ("tiefling",None, {"int": 1,"car": 2}),
])
def test_racial_and_subrace_bonuses(race, subrace, expected):
    catalog, race_data, cls, sub, choices = selection(race, subrace_id=subrace)
    sheet = calculate_creation(catalog, race_data, cls, sub, choices, {})
    assert sheet["stats"] == {key: value + expected.get(key, 0) for key, value in choices["base_stats"].items()}


def test_half_elf_chooses_two_distinct_non_charisma_abilities():
    catalog, race, cls, sub, choices = selection("half_elf")
    choices["racial_abilities"] = ["con","sab"]
    sheet = calculate_creation(catalog, race, cls, sub, choices, {})
    assert sheet["stats"]["car"] == 10
    assert sheet["stats"]["con"] == 14
    assert sheet["stats"]["sab"] == 11
    assert sheet["stats"]["des"] == 12
    for invalid in (["car","con"],["con","con"],["con"]):
        choices["racial_abilities"] = invalid
        with pytest.raises(ValueError):
            calculate_creation(catalog, race, cls, sub, choices, {})


@pytest.mark.parametrize("class_id", ["barbarian","bard","cleric","druid","fighter","monk","paladin","ranger","rogue","sorcerer","warlock","wizard"])
def test_classes_do_not_change_ability_scores_and_assign_saving_throws(class_id):
    catalog, race, cls, sub, choices = selection(class_name=class_id)
    sheet = calculate_creation(catalog, race, cls, sub, choices, {})
    assert sheet["stats"]["fue"] == 14
    assert sheet["stats"]["con"] == 14
    assert [key for key, value in sheet["saves"].items() if value] == [key for key in catalog["abilities"] if key in cls["saves"]]
    assert sheet["hp"] == cls["hit_die"] + 2


def test_elf_perception_and_half_orc_intimidation_are_automatic():
    for race_id, skill in [("elf","percepcion"),("half_orc","intimidacion")]:
        catalog,race,cls,sub,choices = selection(race_id, subrace_id="high_elf" if race_id == "elf" else None)
        assert calculate_creation(catalog,race,cls,sub,choices,{})["skills"][skill] is True


def test_class_skill_options_and_exact_counts_are_enforced():
    catalog,race,cls,sub,choices = selection(class_name="wizard")
    for invalid in (["atletismo","sigilo"], ["arcanos"], ["arcanos","arcanos"]):
        choices["class_skills"] = invalid
        with pytest.raises(ValueError):
            calculate_creation(catalog,race,cls,sub,choices,{})


def test_duplicate_skills_require_replacement_and_never_stack():
    catalog,race,cls,sub,choices = selection("elf", "fighter", "high_elf")
    choices["class_skills"] = ["percepcion","atletismo"]
    choices["replacement_skills"] = []
    with pytest.raises(ValueError):
        calculate_creation(catalog,race,cls,sub,choices,{})
    choices["replacement_skills"] = ["sigilo"]
    sheet = calculate_creation(catalog,race,cls,sub,choices,{})
    assert sheet["skill_bonuses"]["percepcion"] == 2
    assert sheet["skills"]["sigilo"]
    assert sum(sheet["skills"].values()) == 5


def test_expertise_doubles_competence_only_for_selected_proficiencies():
    catalog,race,cls,sub,choices = selection(class_name="rogue")
    choices["class_skills"] = ["sigilo","juego_manos","atletismo","investigacion"]
    choices["expertise"] = ["sigilo","thieves_tools"]
    choices["replacement_skills"] = []
    sheet = calculate_creation(catalog,race,cls,sub,choices,{})
    assert sheet["skill_bonuses"]["sigilo"] == 5  # DES 13: +1, competencia +2 duplicada.
    assert sheet["skill_bonuses"]["juego_manos"] == 3
    assert sheet["tool_expertise"] == ["thieves_tools"]
    choices["expertise"] = ["arcanos","sigilo"]
    with pytest.raises(ValueError):
        calculate_creation(catalog,race,cls,sub,choices,{})


def test_point_buy_validation_and_inputs_are_not_mutated():
    catalog,race,cls,sub,choices = selection()
    original = copy.deepcopy(choices)
    source_sheet = {"background": {"history":"Una aventura"}}
    result = calculate_creation(catalog,race,cls,sub,choices,source_sheet)
    assert choices == original
    assert source_sheet == {"background":{"history":"Una aventura"}}
    assert result["background"]["history"] == "Una aventura"
    for base in (
        {key: 15 for key in catalog["abilities"]},
        {**original["base_stats"], "fue": True},
        {**original["base_stats"], "fue": 16},
        {"fue": 13},
    ):
        choices["base_stats"] = base
        with pytest.raises(ValueError):
            calculate_creation(catalog,race,cls,sub,choices,source_sheet)


def test_hill_dwarf_extra_hp_and_wood_elf_speed():
    for race_id,sub_id,hp,speed in [("dwarf","hill_dwarf",13,25),("elf","wood_elf",11,35)]:
        catalog,race,cls,sub,choices = selection(race_id, subrace_id=sub_id)
        result = calculate_creation(catalog,race,cls,sub,choices,{})
        assert result["hp"] == hp
        assert result["speed"] == speed


def test_checks_and_passive_perception_recalculate_at_level_boundaries():
    sheet = {"stats":{"sab":12,"fue":14}, "saves":{"fue":True}, "skills":{"percepcion":True}, "expertise":[]}
    refreshed = refresh_derived_checks(sheet, 5, creation_catalog())
    assert refreshed["save_bonuses"]["fue"] == 5
    assert refreshed["skill_bonuses"]["percepcion"] == 4
    assert refreshed["passive_perception"] == 14
    assert sheet["stats"] == {"sab":12,"fue":14}
    assert calculate_check_bonus(12,1,True,True) == 5


@pytest.mark.parametrize('cls,expected', [('fighter',11), ('barbarian',13), ('monk',11)])
def test_unarmored_ac_uses_modifiers_and_class_defense(cls, expected):
    catalog,race,class_data,sub,choices = selection(class_name=cls)
    sheet = calculate_creation(catalog,race,class_data,sub,choices,{})
    assert sheet['ac'] == expected


def test_unarmored_defense_does_not_disable_normal_unarmored_calculation():
    catalog,race,cls,sub,choices = selection(class_name='barbarian')
    choices['base_stats']['con'] = 8
    assert calculate_creation(catalog,race,cls,sub,choices,{})['ac'] == 11


def test_background_must_be_an_object():
    catalog,race,cls,sub,choices = selection()
    with pytest.raises(ValueError):
        calculate_creation(catalog,race,cls,sub,choices,{'background':[]})
