"""
Archivo: catalog_seed.py
Propósito: Carga inicial y sincronización de los catálogos y reglas mecánicas de D&D 5e desde archivos JSON hacia la base de datos relacional.
Creador: Alexander Camargo
Modificaciones / Actualizaciones:
- 2026-10-18 [Alexander Camargo]: Creación inicial para migración de datos de catálogo a PostgreSQL/SQLite.
- 2026-10-18 [Alexander Camargo]: Refactorización Clean Code eliminando duplicación (DRY), argumentos de bandera y optimizando verificación de existencia en una sola consulta.
"""
import json
from pathlib import Path
from typing import Any

from sqlalchemy.orm import Session

from app.db.models import (
    DndBackground,
    DndClass,
    DndRace,
    DndRuleConfig,
    DndSkill,
    DndSubrace,
)
from app.db.session import Base

DATA_DIR = Path(__file__).resolve().parents[1] / "data"

RULE_CONFIG_KEYS = (
    "ability_keys",
    "point_budget",
    "point_costs",
    "ability_limit",
    "base_min",
    "base_max",
    "bonus_choice_options",
    "bonus_choice_amount",
    "initial_expertise",
    "unarmored_defense",
    "tool_labels",
)


def seed_catalogs(db: Session) -> None:
    """Puebla las tablas de catálogo D&D 5e si están vacías."""
    Base.metadata.create_all(bind=db.get_bind())
    if db.query(DndRace).first() is not None:
        return

    _seed_rules_and_skills(db, _load_json("creation_rules"))
    _seed_races(db, _load_json("races"))
    _seed_classes(db, _load_json("classes"))
    _seed_backgrounds(db, _load_json("backgrounds"))
    db.commit()


def _load_json(filename: str) -> Any:
    path = DATA_DIR / f"{filename}.json"
    return json.loads(path.read_text(encoding="utf-8"))


def _seed_rules_and_skills(db: Session, mechanics: dict) -> None:
    for skill in mechanics.get("skills", []):
        db.add(DndSkill(
            id=skill["id"],
            key=skill["key"],
            name=skill["name"],
            ability=skill["ability"],
        ))
    for key in RULE_CONFIG_KEYS:
        if key in mechanics:
            db.add(DndRuleConfig(key=key, data=mechanics[key]))


def _seed_races(db: Session, races: list[dict]) -> None:
    for race in races:
        db.add(DndRace(
            slug=race["slug"],
            name=race["name"],
            size=race.get("size", "Mediano"),
            speed=race.get("speed", 30),
            ability_bonuses=race.get("ability_bonuses", {}),
            languages=race.get("languages", []),
            extra_languages=race.get("extra_languages", 0),
            skills=race.get("skills", []),
            skill_choices=race.get("skill_choices", 0),
            bonus_choices=race.get("bonus_choices", 0),
            proficiencies=race.get("proficiencies", []),
            traits=race.get("traits", []),
            description=race.get("description", ""),
        ))
        for sub in race.get("subraces", []):
            db.add(DndSubrace(
                slug=sub["slug"],
                race_slug=race["slug"],
                name=sub["name"],
                ability_bonuses=sub.get("ability_bonuses", {}),
                speed=sub.get("speed"),
                hp_per_level=sub.get("hp_per_level", 0),
                proficiencies=sub.get("proficiencies", []),
                traits=sub.get("traits", []),
            ))


def _seed_classes(db: Session, classes: list[dict]) -> None:
    for cls in classes:
        db.add(DndClass(
            slug=cls["slug"],
            name=cls["name"],
            description=cls.get("description", ""),
            hit_die=cls["hit_die"],
            primary_abilities=cls.get("primary_abilities", []),
            saving_throws=cls.get("saving_throws", []),
            skill_choices=cls.get("skill_choices", {}),
            proficiencies=cls.get("proficiencies", []),
            spellcasting=cls.get("spellcasting"),
            recommended_abilities=cls.get("recommended_abilities", []),
            starting_ac=cls.get("starting_ac", {}),
            starting_attacks=cls.get("starting_attacks", []),
            starting_equipment=cls.get("starting_equipment", []),
            subclass_label=cls.get("subclass_label", ""),
            subclass_level=cls.get("subclass_level", 3),
            features=cls.get("features", {}),
        ))


def _seed_backgrounds(db: Session, backgrounds: list[dict]) -> None:
    for bg in backgrounds:
        db.add(DndBackground(
            slug=bg["slug"],
            name=bg["name"],
            skills=bg.get("skills", []),
            extra_languages=bg.get("extra_languages", 0),
            proficiencies=bg.get("proficiencies", []),
            feature=bg.get("feature", {}),
            equipment=bg.get("equipment", []),
        ))
