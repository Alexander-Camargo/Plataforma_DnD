"""Catálogo de creación a partir de las tablas de la base de datos (D&D 5e).

Los datos de catálogo (razas, subrazas, clases, trasfondos, habilidades y mecánicas)
se consultan directamente desde la base de datos relacional.
"""
from sqlalchemy.orm import Session
from app.db.session import SessionLocal
from app.db.models import (
    DndRace,
    DndClass,
    DndBackground,
    DndSkill,
    DndRuleConfig,
)
from app.db.session import Base
from app.db.catalog_seed import seed_catalogs

_CATALOG_CACHE: dict | None = None


def creation_catalog(db: Session | None = None, reload: bool = False) -> dict:
    """Construye el catálogo de creación consultando los modelos relacionales en la BD."""
    global _CATALOG_CACHE
    if _CATALOG_CACHE is not None and not reload:
        return _CATALOG_CACHE

    should_close = False
    if db is None:
        db = SessionLocal()
        should_close = True

    try:
        # Si la base de datos aún no tiene las tablas creadas o catálogos sembrados
        Base.metadata.create_all(bind=db.get_bind())
        if db.query(DndRace).count() == 0:
            seed_catalogs(db)

        # 1. Habilidades y mapeo de características
        skills_rows = db.query(DndSkill).all()
        skills = {item.id: item.key for item in skills_rows}
        all_skills = list(skills.values())

        configs = {
            cfg.key: (cfg.data.get("data", cfg.data) if isinstance(cfg.data, dict) else cfg.data)
            for cfg in db.query(DndRuleConfig).all()
        }
        ability_keys = configs.get("ability_keys", {
            "str": "fue", "dex": "des", "con": "con",
            "int": "int", "wis": "sab", "cha": "car"
        })

        def abilities(values):
            return {ability_keys[key]: value for key, value in values.items()}

        # 2. Razas y Subrazas
        races_rows = db.query(DndRace).all()
        races = []
        for race in races_rows:
            bonus_amount_val = configs.get("bonus_choice_amount", 1)
            bonus_options_list = (
                [ability_keys[key] for key in configs.get("bonus_choice_options", [])]
                if race.bonus_choices
                else []
            )

            races.append({
                "id": race.slug,
                "name": race.name,
                "legacy_names": [race.name, "Tiefling"] if race.slug == "tiefling" else [race.name],
                "bonuses": abilities(race.ability_bonuses),
                "speed": race.speed,
                "fixed_skills": [skills[key] for key in race.skills if key in skills],
                "skill_count": race.skill_choices,
                "bonus_count": race.bonus_choices,
                "bonus_options": bonus_options_list,
                "bonus_amount": bonus_amount_val,
                "subraces": [{
                    "id": sub.slug,
                    "name": sub.name,
                    "bonuses": abilities(sub.ability_bonuses),
                    "speed": sub.speed if sub.speed is not None else race.speed,
                    "hp_per_level": sub.hp_per_level,
                } for sub in race.subraces],
            })

        # 3. Clases
        initial_expertise = configs.get("initial_expertise", {})
        unarmored_defense = configs.get("unarmored_defense", {})
        classes_rows = db.query(DndClass).all()
        classes = []
        for cls in classes_rows:
            choice = cls.skill_choices
            expertise = initial_expertise.get(cls.slug, {"count": 0, "tools": []})
            classes.append({
                "id": cls.slug,
                "name": cls.name,
                "legacy_slug": cls.name.lower(),
                "hit_die": cls.hit_die,
                "saves": [ability_keys[key] for key in cls.saving_throws if key in ability_keys],
                "skill_count": choice.get("count", 0),
                "skill_options": all_skills if choice.get("options") == "any" else [skills[key] for key in choice.get("options", []) if key in skills],
                "recommended": [ability_keys[key] for key in cls.recommended_abilities if key in ability_keys],
                "primary": [ability_keys[key] for key in cls.primary_abilities if key in ability_keys],
                "expertise_count": expertise.get("count", 0),
                "expertise_tools": expertise.get("tools", []),
                "unarmored_abilities": [ability_keys[key] for key in unarmored_defense.get(cls.slug, ["dex"]) if key in ability_keys],
            })

        # 4. Trasfondos
        backgrounds_rows = db.query(DndBackground).all()
        backgrounds = [
            {
                "id": item.slug,
                "name": item.name,
                "skills": [skills[key] for key in item.skills if key in skills],
                "source": "SRD 5.1" if item.slug == "acolyte" else "Catálogo del proyecto"
            }
            for item in backgrounds_rows
        ]

        result = {
            "edition": "5e-2014",
            "abilities": list(ability_keys.values()),
            "point_budget": configs.get("point_budget", 27),
            "point_costs": configs.get("point_costs", {}),
            "base_min": configs.get("base_min", 8),
            "base_max": configs.get("base_max", 15),
            "ability_limit": configs.get("ability_limit", 20),
            "skills": [
                {"key": item.key, "name": item.name, "ability": ability_keys.get(item.ability, item.ability)}
                for item in skills_rows
            ],
            "races": races,
            "classes": classes,
            "backgrounds": backgrounds,
            "tool_labels": configs.get("tool_labels", {}),
        }
        _CATALOG_CACHE = result
        return result
    finally:
        if should_close:
            db.close()


def find_option(options, value, kind):
    folded = value.casefold()
    for option in options:
        aliases = [option["id"], option["name"], option.get("legacy_slug", ""), *option.get("legacy_names", [])]
        if folded in [alias.casefold() for alias in aliases if alias]:
            return option
    raise ValueError(f"{kind} no válido: {value}")
