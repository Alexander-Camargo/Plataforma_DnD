"""
Archivo: rules_catalog.py
Propósito: Proveer el catálogo de creación de personajes de D&D 5e consultando las tablas de la base de datos y adaptando a las claves españolas del frontend sin migrarlas.
Creador: Joshua Pérez Bullen
Modificaciones / Actualizaciones:
- 2026-10-12 [Joshua Pérez Bullen]: Implementación inicial basada en lectura de archivos JSON estáticos.
- 2026-10-18 [Alexander Camargo]: Migración de consulta de datos desde tablas relacionales en base de datos.
- 2026-10-18 [Alexander Camargo]: Refactorización Clean Code con funciones pequeñas (< 20 líneas), eliminación de caché mutable global y soporte para inyección de sesión de BD.
"""
from sqlalchemy.orm import Session

from app.db.catalog_seed import seed_catalogs
from app.db.models import (
    DndBackground,
    DndClass,
    DndRace,
    DndRuleConfig,
    DndSkill,
)
from app.db.session import SessionLocal


def creation_catalog(db: Session | None = None) -> dict:
    """Construye el catálogo de creación consultando las tablas de la base de datos."""
    if db is not None:
        return _build_catalog(db)
    with SessionLocal() as session:
        return _build_catalog(session)


def _build_catalog(db: Session) -> dict:
    seed_catalogs(db)
    skills_rows = db.query(DndSkill).all()
    skills = {item.id: item.key for item in skills_rows}
    configs = {cfg.key: cfg.data for cfg in db.query(DndRuleConfig).all()}
    ability_keys = configs["ability_keys"]

    return {
        "edition": "5e-2014",
        "abilities": list(ability_keys.values()),
        "point_budget": configs["point_budget"],
        "point_costs": configs["point_costs"],
        "base_min": configs["base_min"],
        "base_max": configs["base_max"],
        "ability_limit": configs["ability_limit"],
        "skills": [
            {"key": item.key, "name": item.name, "ability": ability_keys[item.ability]}
            for item in skills_rows
        ],
        "races": [
            _format_race(race, ability_keys, skills, configs)
            for race in db.query(DndRace).all()
        ],
        "classes": [
            _format_class(cls, ability_keys, skills, configs)
            for cls in db.query(DndClass).all()
        ],
        # Solo nombres y mecánica: no se exportan descripciones no incluidas en SRD.
        "backgrounds": [
            _format_background(bg, skills)
            for bg in db.query(DndBackground).all()
        ],
        "tool_labels": configs["tool_labels"],
    }


def _map_abilities(values: dict, ability_keys: dict) -> dict:
    return {ability_keys[key]: value for key, value in values.items()}


def _format_race(race: DndRace, ability_keys: dict, skills: dict, configs: dict) -> dict:
    bonus_options = (
        [ability_keys[key] for key in configs["bonus_choice_options"]]
        if race.bonus_choices
        else []
    )
    return {
        "id": race.slug,
        "name": race.name,
        "legacy_names": [race.name, "Tiefling"] if race.slug == "tiefling" else [race.name],
        "bonuses": _map_abilities(race.ability_bonuses, ability_keys),
        "speed": race.speed,
        "fixed_skills": [skills[key] for key in race.skills],
        "skill_count": race.skill_choices,
        "bonus_count": race.bonus_choices,
        "bonus_options": bonus_options,
        "bonus_amount": configs["bonus_choice_amount"],
        "traits": race.traits or [],
        "subraces": [
            {
                "id": sub.slug,
                "name": sub.name,
                "bonuses": _map_abilities(sub.ability_bonuses, ability_keys),
                "speed": sub.speed if sub.speed is not None else race.speed,
                "hp_per_level": sub.hp_per_level,
                "traits": sub.traits or [],
            }
            for sub in race.subraces
        ],
    }


def _format_class(cls: DndClass, ability_keys: dict, skills: dict, configs: dict) -> dict:
    choice = cls.skill_choices
    all_skills = list(skills.values())
    expertise = configs["initial_expertise"].get(cls.slug, {"count": 0, "tools": []})
    unarmored = configs["unarmored_defense"].get(cls.slug, ["dex"])
    return {
        "id": cls.slug,
        "name": cls.name,
        "legacy_slug": cls.name.lower(),
        "hit_die": cls.hit_die,
        "saves": [ability_keys[key] for key in cls.saving_throws],
        "skill_count": choice["count"],
        "skill_options": (
            all_skills
            if choice["options"] == "any"
            else [skills[key] for key in choice["options"]]
        ),
        "recommended": [ability_keys[key] for key in cls.recommended_abilities],
        "primary": [ability_keys[key] for key in cls.primary_abilities],
        "expertise_count": expertise["count"],
        "expertise_tools": expertise["tools"],
        "unarmored_abilities": [ability_keys[key] for key in unarmored],
        "subclass_label": cls.subclass_label or "Subclase",
        "subclass_level": cls.subclass_level or 3,
        "features": cls.features or {},
    }


def _format_background(bg: DndBackground, skills: dict) -> dict:
    return {
        "id": bg.slug,
        "name": bg.name,
        "skills": [skills[key] for key in bg.skills],
        "source": "SRD 5.1" if bg.slug == "acolyte" else "Catálogo del proyecto",
    }


def find_option(options, value, kind):
    folded = value.casefold()
    for option in options:
        aliases = [option["id"], option["name"], option.get("legacy_slug", ""), *option.get("legacy_names", [])]
        if folded in [alias.casefold() for alias in aliases if alias]:
            return option
    raise ValueError(f"{kind} no válido: {value}")
