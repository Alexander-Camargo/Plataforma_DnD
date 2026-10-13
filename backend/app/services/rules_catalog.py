"""Catálogo de creación a partir de las tablas del backend.

Los slugs ingleses siguen siendo canónicos en los datos de reglas. El DTO
adapta a las claves españolas ya guardadas en las hojas, sin migrarlas.
"""
import json
from functools import lru_cache
from pathlib import Path

DATA_DIR = Path(__file__).resolve().parents[1] / "data"


@lru_cache
def creation_catalog() -> dict:
    def load(name):
        return json.loads((DATA_DIR / (name + ".json")).read_text(encoding="utf-8"))
    mechanics = load("creation_rules")
    ability_keys = mechanics["ability_keys"]
    skills = {item["id"]: item["key"] for item in mechanics["skills"]}
    all_skills = list(skills.values())

    def abilities(values):
        return {ability_keys[key]: value for key, value in values.items()}

    races = []
    for race in load("races"):
        races.append({
            "id": race["slug"], "name": race["name"],
            "legacy_names": [race["name"], "Tiefling"] if race["slug"] == "tiefling" else [race["name"]],
            "bonuses": abilities(race["ability_bonuses"]), "speed": race["speed"],
            "fixed_skills": [skills[key] for key in race.get("skills", [])],
            "skill_count": race.get("skill_choices", 0),
            "bonus_count": race.get("bonus_choices", 0),
            "bonus_options": [ability_keys[key] for key in mechanics["bonus_choice_options"]] if race.get("bonus_choices") else [],
            "bonus_amount": mechanics["bonus_choice_amount"],
            "subraces": [{
                "id": sub["slug"], "name": sub["name"], "bonuses": abilities(sub["ability_bonuses"]),
                "speed": sub.get("speed", race["speed"]), "hp_per_level": sub.get("hp_per_level", 0),
            } for sub in race.get("subraces", [])],
        })
    classes = []
    for cls in load("classes"):
        choice = cls["skill_choices"]
        expertise = mechanics["initial_expertise"].get(cls["slug"], {"count": 0, "tools": []})
        classes.append({
            "id": cls["slug"], "name": cls["name"], "legacy_slug": cls["name"].lower(),
            "hit_die": cls["hit_die"],
            "saves": [ability_keys[key] for key in cls["saving_throws"]],
            "skill_count": choice["count"],
            "skill_options": all_skills if choice["options"] == "any" else [skills[key] for key in choice["options"]],
            "recommended": [ability_keys[key] for key in cls.get("recommended_abilities", [])],
            "primary": [ability_keys[key] for key in cls.get("primary_abilities", [])],
            "expertise_count": expertise["count"], "expertise_tools": expertise["tools"],
            "unarmored_abilities": [ability_keys[key] for key in mechanics["unarmored_defense"].get(cls["slug"], ["dex"])],
        })
    return {
        "edition": "5e-2014", "abilities": list(ability_keys.values()),
        "point_budget": mechanics["point_budget"], "point_costs": mechanics["point_costs"],
        "base_min": mechanics["base_min"], "base_max": mechanics["base_max"],
        "ability_limit": mechanics["ability_limit"],
        "skills": [{"key": item["key"], "name": item["name"], "ability": ability_keys[item["ability"]]}
                   for item in mechanics["skills"]],
        "races": races, "classes": classes,
        # Solo nombres y mecánica: no se exportan descripciones no incluidas en SRD.
        "backgrounds": [{"id": item["slug"], "name": item["name"], "skills": [skills[key] for key in item["skills"]],
                         "source": "SRD 5.1" if item["slug"] == "acolyte" else "Catálogo del proyecto"}
                        for item in load("backgrounds")],
        "tool_labels": mechanics["tool_labels"],
    }


def find_option(options, value, kind):
    folded = value.casefold()
    for option in options:
        aliases = [option["id"], option["name"], option.get("legacy_slug", ""), *option.get("legacy_names", [])]
        if folded in [alias.casefold() for alias in aliases if alias]:
            return option
    raise ValueError(f"{kind} no válido: {value}")

