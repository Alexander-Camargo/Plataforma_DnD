"""Carga y sincronización de catálogos y reglas D&D 5e hacia la Base de Datos."""
import json
from pathlib import Path
from sqlalchemy.orm import Session

from app.db.models import (
    DndRace,
    DndSubrace,
    DndClass,
    DndBackground,
    DndSkill,
    DndRuleConfig,
)

DATA_DIR = Path(__file__).resolve().parents[1] / "data"


def load_json(filename: str):
    path = DATA_DIR / f"{filename}.json"
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def seed_catalogs(db: Session, force: bool = False) -> None:
    """Inserta o actualiza en la base de datos todos los catálogos del juego."""
    # 1. Reglas de Creación y Habilidades
    mechanics = load_json("creation_rules")
    if mechanics:
        for skill_data in mechanics.get("skills", []):
            existing = db.get(DndSkill, skill_data["id"])
            if not existing:
                db.add(DndSkill(
                    id=skill_data["id"],
                    key=skill_data["key"],
                    name=skill_data["name"],
                    ability=skill_data["ability"],
                ))
            elif force:
                existing.key = skill_data["key"]
                existing.name = skill_data["name"]
                existing.ability = skill_data["ability"]

        # Configuración general
        config_keys = [
            "ability_keys", "point_budget", "point_costs", "ability_limit",
            "base_min", "base_max", "bonus_choice_options", "bonus_choice_amount",
            "initial_expertise", "unarmored_defense", "tool_labels"
        ]
        for key in config_keys:
            if key in mechanics:
                cfg_data = {"data": mechanics[key]}
                existing_cfg = db.get(DndRuleConfig, key)
                if not existing_cfg:
                    db.add(DndRuleConfig(key=key, data=cfg_data))
                elif force:
                    existing_cfg.data = cfg_data

    # 2. Razas y Subrazas
    races_data = load_json("races")
    if races_data:
        for r in races_data:
            race = db.get(DndRace, r["slug"])
            if not race:
                race = DndRace(
                    slug=r["slug"],
                    name=r["name"],
                    size=r.get("size", "Mediano"),
                    speed=r.get("speed", 30),
                    ability_bonuses=r.get("ability_bonuses", {}),
                    languages=r.get("languages", []),
                    extra_languages=r.get("extra_languages", 0),
                    skills=r.get("skills", []),
                    skill_choices=r.get("skill_choices", 0),
                    bonus_choices=r.get("bonus_choices", 0),
                    proficiencies=r.get("proficiencies", []),
                    traits=r.get("traits", []),
                    description=r.get("description", ""),
                )
                db.add(race)
            elif force:
                race.name = r["name"]
                race.size = r.get("size", "Mediano")
                race.speed = r.get("speed", 30)
                race.ability_bonuses = r.get("ability_bonuses", {})
                race.languages = r.get("languages", [])
                race.extra_languages = r.get("extra_languages", 0)
                race.skills = r.get("skills", [])
                race.skill_choices = r.get("skill_choices", 0)
                race.bonus_choices = r.get("bonus_choices", 0)
                race.proficiencies = r.get("proficiencies", [])
                race.traits = r.get("traits", [])
                race.description = r.get("description", "")

            # Subrazas
            for sub in r.get("subraces", []):
                subrace = db.get(DndSubrace, sub["slug"])
                if not subrace:
                    db.add(DndSubrace(
                        slug=sub["slug"],
                        race_slug=r["slug"],
                        name=sub["name"],
                        ability_bonuses=sub.get("ability_bonuses", {}),
                        speed=sub.get("speed"),
                        hp_per_level=sub.get("hp_per_level", 0),
                        proficiencies=sub.get("proficiencies", []),
                        traits=sub.get("traits", []),
                    ))
                elif force:
                    subrace.name = sub["name"]
                    subrace.ability_bonuses = sub.get("ability_bonuses", {})
                    subrace.speed = sub.get("speed")
                    subrace.hp_per_level = sub.get("hp_per_level", 0)
                    subrace.proficiencies = sub.get("proficiencies", [])
                    subrace.traits = sub.get("traits", [])

    # 3. Clases
    classes_data = load_json("classes")
    if classes_data:
        for c in classes_data:
            cls = db.get(DndClass, c["slug"])
            if not cls:
                db.add(DndClass(
                    slug=c["slug"],
                    name=c["name"],
                    description=c.get("description", ""),
                    hit_die=c["hit_die"],
                    primary_abilities=c.get("primary_abilities", []),
                    saving_throws=c.get("saving_throws", []),
                    skill_choices=c.get("skill_choices", {}),
                    proficiencies=c.get("proficiencies", []),
                    spellcasting=c.get("spellcasting"),
                    recommended_abilities=c.get("recommended_abilities", []),
                    starting_ac=c.get("starting_ac", {}),
                    starting_attacks=c.get("starting_attacks", []),
                    starting_equipment=c.get("starting_equipment", []),
                    subclass_label=c.get("subclass_label", ""),
                    subclass_level=c.get("subclass_level", 3),
                    features=c.get("features", {}),
                ))
            elif force:
                cls.name = c["name"]
                cls.description = c.get("description", "")
                cls.hit_die = c["hit_die"]
                cls.primary_abilities = c.get("primary_abilities", [])
                cls.saving_throws = c.get("saving_throws", [])
                cls.skill_choices = c.get("skill_choices", {})
                cls.proficiencies = c.get("proficiencies", [])
                cls.spellcasting = c.get("spellcasting")
                cls.recommended_abilities = c.get("recommended_abilities", [])
                cls.starting_ac = c.get("starting_ac", {})
                cls.starting_attacks = c.get("starting_attacks", [])
                cls.starting_equipment = c.get("starting_equipment", [])
                cls.subclass_label = c.get("subclass_label", "")
                cls.subclass_level = c.get("subclass_level", 3)
                cls.features = c.get("features", {})

    # 4. Trasfondos
    backgrounds_data = load_json("backgrounds")
    if backgrounds_data:
        for b in backgrounds_data:
            bg = db.get(DndBackground, b["slug"])
            if not bg:
                db.add(DndBackground(
                    slug=b["slug"],
                    name=b["name"],
                    skills=b.get("skills", []),
                    extra_languages=b.get("extra_languages", 0),
                    proficiencies=b.get("proficiencies", []),
                    feature=b.get("feature", {}),
                    equipment=b.get("equipment", []),
                ))
            elif force:
                bg.name = b["name"]
                bg.skills = b.get("skills", [])
                bg.extra_languages = b.get("extra_languages", 0)
                bg.proficiencies = b.get("proficiencies", [])
                bg.feature = b.get("feature", {})
                bg.equipment = b.get("equipment", [])

    db.commit()
