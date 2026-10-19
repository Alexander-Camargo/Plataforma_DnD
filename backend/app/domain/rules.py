"""
Archivo: rules.py
Propósito: Motor de reglas puras de D&D 5e (2014) para creación de personajes, subida de nivel, mejoras de característica (ASI), tabla de experiencia (XP) e hitos, sin acoplamiento a base de datos ni HTTP.
Creador: Alexander Camargo / Joshua Pérez Bullen
Modificaciones / Actualizaciones:
- 2026-10-08 [Alexander Camargo]: Fórmulas base de modificadores, competencia y percepción pasiva.
- 2026-10-12 [Joshua Pérez Bullen]: Validación completa de creación de nivel 1 (point-buy, competencias, pericias y CA sin armadura).
- 2026-10-18 [Alexander Camargo]: Implementación de subida de nivel guiada (Hito 3.1), cálculo de PG por nivel (media o tirada + CON retroactivo), validación de ASI (+2 o +1/+1 hasta 20), arquetipos y desbloqueo progresivo de rasgos.
- 2026-10-18 [Alexander Camargo]: Definición de la tabla oficial de experiencia (XP_THRESHOLDS) y verificación de umbral de nivel por hitos de campaña.
"""
import math
from copy import deepcopy

XP_THRESHOLDS = {
    1: 0,
    2: 300,
    3: 900,
    4: 2700,
    5: 6500,
    6: 14000,
    7: 23000,
    8: 34000,
    9: 48000,
    10: 64000,
    11: 85000,
    12: 100000,
    13: 120000,
    14: 140000,
    15: 165000,
    16: 195000,
    17: 225000,
    18: 265000,
    19: 305000,
    20: 355000,
}


def xp_for_level(level: int) -> int:
    """Devuelve la cantidad de experiencia necesaria para alcanzar el nivel dado (D&D 5e)."""
    if level <= 1:
        return 0
    return XP_THRESHOLDS.get(min(level, 20), 355000)


def calculate_modifier(score: int) -> int:
    """Calcula el modificador, redondeando hacia abajo."""
    return math.floor((score - 10) / 2)


def calculate_proficiency_bonus(level: int) -> int:
    """Calcula el bonificador de competencia según nivel."""
    return math.floor((level - 1) / 4) + 2


def format_modifier(mod: int) -> str:
    return f"+{mod}" if mod >= 0 else str(mod)


def calculate_passive_perception(wis_score: int, has_proficiency: bool, level: int) -> int:
    return 10 + calculate_modifier(wis_score) + (calculate_proficiency_bonus(level) if has_proficiency else 0)


def calculate_check_bonus(score, level, proficient=False, expertise=False):
    """Solo suma competencia (o pericia) cuando corresponde."""
    return calculate_modifier(score) + (calculate_proficiency_bonus(level) * (2 if expertise else 1) if proficient else 0)


def collect_features(race: dict, subrace: dict | None, cls: dict, level: int, subclass: str | None = None) -> list[dict]:
    """Recopila los rasgos raciales y de clase desbloqueados hasta el nivel indicado."""
    features: list[dict] = []
    for trait in race.get("traits", []):
        if isinstance(trait, dict):
            features.append({"name": trait["name"], "description": trait.get("description", ""), "source": race["name"]})
    for trait in (subrace or {}).get("traits", []):
        if isinstance(trait, dict):
            features.append({"name": trait["name"], "description": trait.get("description", ""), "source": subrace["name"]})
    class_features = cls.get("features", {})
    for lvl in range(1, level + 1):
        for feat in class_features.get(str(lvl), []):
            if isinstance(feat, dict):
                name = feat["name"]
                if subclass and lvl == cls.get("subclass_level") and name == cls.get("subclass_label"):
                    name = f"{name}: {subclass}"
                features.append({
                    "name": name,
                    "description": feat.get("description", ""),
                    "source": f"{cls['name']} (Nivel {lvl})",
                    "level": lvl,
                })
    return features


def calculate_creation(catalog: dict, race: dict, cls: dict, subrace: dict | None,
                       choices: dict, original_sheet: dict) -> dict:
    """Valida elecciones y produce una hoja de nivel 1 en claves españolas.

    La clase no asigna puntuaciones: recibe el reparto del jugador.
    Las competencias repetidas se sustituyen, no se suman dos veces.
    """
    abilities = catalog["abilities"]
    base = choices["base_stats"]
    if set(base) != set(abilities) or any(type(value) is not int for value in base.values()):
        raise ValueError("Reparte las seis características con valores enteros.")
    if any(value < catalog["base_min"] or value > catalog["base_max"] for value in base.values()):
        raise ValueError("Las puntuaciones base deben estar entre 8 y 15.")
    spent = sum(catalog["point_costs"][str(value)] for value in base.values())
    if spent > catalog["point_budget"]:
        raise ValueError("La compra de puntos supera el presupuesto de 27.")
    selected = choices.get("racial_abilities", [])
    if len(selected) != race["bonus_count"] or len(set(selected)) != len(selected):
        raise ValueError("Elige las características raciales indicadas, sin repetirlas.")
    if any(key not in race["bonus_options"] for key in selected):
        raise ValueError("Ese bonificador racial no puede asignarse a esa característica.")
    bonuses = {key: race["bonuses"].get(key, 0) + (subrace or {}).get("bonuses", {}).get(key, 0)
               for key in abilities}
    for key in selected:
        bonuses[key] += race["bonus_amount"]
    stats = {key: base[key] + bonuses[key] for key in abilities}
    if any(value > catalog["ability_limit"] for value in stats.values()):
        raise ValueError("Las características no pueden superar 20.")

    all_skills = {item["key"]: item for item in catalog["skills"]}
    class_skills = choices.get("class_skills", [])
    race_skills = choices.get("race_skills", [])
    def validate_selection(selected_skills, count, allowed, message):
        if len(selected_skills) != count or len(set(selected_skills)) != len(selected_skills):
            raise ValueError(message)
        if any(key not in allowed for key in selected_skills):
            raise ValueError(message)
    validate_selection(class_skills, cls["skill_count"], cls["skill_options"],
                       "Elige el número correcto de habilidades de tu clase, entre las permitidas.")
    validate_selection(race_skills, race["skill_count"], all_skills,
                       "Elige las habilidades raciales indicadas, sin repetirlas.")
    background_id = choices.get("background_id")
    background = next((item for item in catalog["backgrounds"] if item["id"] == background_id), None)
    if not background:
        raise ValueError("Elige un trasfondo válido.")
    grants = [*race["fixed_skills"], *class_skills, *race_skills, *background["skills"]]
    unique = set(grants)
    replacements = choices.get("replacement_skills", [])
    validate_selection(replacements, len(grants) - len(unique), set(all_skills) - unique,
                       "Sustituye las competencias repetidas por otras habilidades distintas.")
    unique.update(replacements)
    expertise = choices.get("expertise", [])
    validate_selection(expertise, cls["expertise_count"], unique | set(cls["expertise_tools"]),
                       "Elige las pericias indicadas entre tus competencias o herramientas permitidas.")

    if not isinstance(original_sheet.get("background", {}), dict):
        raise ValueError("El trasfondo debe ser un objeto.")
    sheet = deepcopy(original_sheet)
    sheet["stats"] = stats
    sheet["modifiers"] = {key: calculate_modifier(value) for key, value in stats.items()}
    sheet["saves"] = {key: key in cls["saves"] for key in abilities}
    sheet["skills"] = {key: key in unique for key in all_skills}
    sheet["expertise"] = [key for key in expertise if key in all_skills]
    sheet["tool_expertise"] = [key for key in expertise if key in cls["expertise_tools"]]
    sheet["skill_bonuses"] = {key: calculate_check_bonus(stats[item["ability"]], 1, key in unique, key in expertise)
                            for key, item in all_skills.items()}
    sheet["save_bonuses"] = {key: calculate_check_bonus(value, 1, key in cls["saves"]) for key, value in stats.items()}
    sheet["proficiency_bonus"] = calculate_proficiency_bonus(1)
    sheet["passive_perception"] = 10 + sheet["skill_bonuses"]["percepcion"]
    sheet["hp"] = max(1, cls["hit_die"] + sheet["modifiers"]["con"]) + (subrace or {}).get("hp_per_level", 0)
    sheet["speed"] = (subrace or race)["speed"]
    sheet["initiative"] = sheet["modifiers"]["des"]
    # El asistente aún no elige equipo: esta CA es explícitamente sin armadura.
    sheet["ac"] = max(10 + sheet["modifiers"]["des"], 10 + sum(sheet["modifiers"][key] for key in cls["unarmored_abilities"]))
    sheet["equipment"] = []
    sheet["features"] = collect_features(race, subrace, cls, 1)
    sheet["creation"] = {**deepcopy(choices), "edition": catalog["edition"],
                         "race_id": race["id"], "class_id": cls["id"],
                         "subrace_id": subrace["id"] if subrace else None, "point_cost": spent}
    sheet["background"] = {**sheet.get("background", {}), "id": background["id"], "name": background["name"]}
    return sheet


def _validate_and_apply_asi(stats: dict, asi: dict, has_asi: bool, catalog: dict, class_name: str, level: int) -> dict:
    """Valida y aplica una Mejora de Característica (+2 o +1/+1, tope 20)."""
    if asi and not has_asi:
        raise ValueError(f"El nivel {level} de {class_name} no otorga Mejora de Característica (ASI).")
    if not asi:
        return dict(stats)
    abilities = set(catalog["abilities"])
    if (
        any(k not in abilities for k in asi)
        or any(type(v) is not int or v not in (1, 2) for v in asi.values())
        or sum(asi.values()) != 2
    ):
        raise ValueError("En una Mejora de Característica (ASI) debes repartir exactamente +2 a un atributo o +1 a dos atributos distintos.")
    updated = dict(stats)
    for key, delta in asi.items():
        updated[key] = updated.get(key, 10) + delta
        if updated[key] > catalog["ability_limit"]:
            raise ValueError("Las características no pueden superar 20.")
    return updated


def _calculate_level_up_hp(current_hp: int, cls: dict, subrace: dict | None,
                           old_con_mod: int, new_con_mod: int, current_level: int,
                           hp_roll: int | None) -> int:
    """Calcula el nuevo máximo de PG según D&D 5e (media fija o tirada + CON retroactivo)."""
    hit_die = cls["hit_die"]
    if hp_roll is not None:
        if type(hp_roll) is not int or not (1 <= hp_roll <= hit_die):
            raise ValueError(f"La tirada de dado de golpe debe estar entre 1 y {hit_die}.")
        die_value = hp_roll
    else:
        die_value = (hit_die // 2) + 1
    retroactive_hp = max(0, (new_con_mod - old_con_mod) * current_level)
    hp_gain = max(1, die_value + new_con_mod) + (subrace or {}).get("hp_per_level", 0)
    return current_hp + retroactive_hp + hp_gain


def apply_level_up(catalog: dict, race: dict, cls: dict, subrace: dict | None,
                   current_level: int, sheet: dict, choices: dict | None = None) -> dict:
    """Aplica la subida de un nivel (PG, ASI, subclase, rasgos y bonos derivados) según D&D 5e."""
    new_level = current_level + 1
    if new_level > 20:
        raise ValueError("El nivel máximo en D&D 5e es 20.")
    choices = choices or {}
    result = deepcopy(sheet)
    old_stats = result.get("stats", {k: 10 for k in catalog["abilities"]})
    old_mods = {k: calculate_modifier(old_stats.get(k, 10)) for k in catalog["abilities"]}

    level_features = cls.get("features", {}).get(str(new_level), [])
    has_asi = "ASI" in level_features
    new_stats = _validate_and_apply_asi(old_stats, choices.get("asi") or {}, has_asi, catalog, cls["name"], new_level)
    result["stats"] = new_stats

    subclass_in = (choices.get("subclass") or "").strip()
    subclass_level = cls.get("subclass_level", 3)
    if subclass_in and (new_level < subclass_level or result.get("subclass")):
        raise ValueError(f"La subclase ({cls.get('subclass_label', 'Subclase')}) solo se elige al alcanzar el nivel {subclass_level}.")
    if subclass_in:
        result["subclass"] = subclass_in

    new_con_mod = calculate_modifier(new_stats.get("con", 10))
    current_hp = result.get("hp", max(1, cls["hit_die"] + old_mods["con"]))
    result["hp"] = _calculate_level_up_hp(
        current_hp, cls, subrace, old_mods["con"], new_con_mod, current_level, choices.get("hp_roll")
    )

    result = refresh_derived_checks(result, new_level, catalog)
    result["initiative"] = result["modifiers"]["des"]
    old_unarmored_ac = max(10 + old_mods["des"], 10 + sum(old_mods[k] for k in cls["unarmored_abilities"]))
    if result.get("ac") == old_unarmored_ac:
        result["ac"] = max(10 + result["modifiers"]["des"],
                           10 + sum(result["modifiers"][k] for k in cls["unarmored_abilities"]))

    result["features"] = collect_features(race, subrace, cls, new_level, result.get("subclass"))
    return result


def refresh_derived_checks(sheet: dict, level: int, catalog: dict) -> dict:
    """Recalcula totales de hoja sin cambiar reparto ni competencias históricas."""
    result = deepcopy(sheet)
    stats = result.get("stats", {})
    if not isinstance(stats, dict) or any(type(value) is not int or not 1 <= value <= 20 for value in stats.values()):
        raise ValueError("Las puntuaciones deben ser enteros entre 1 y 20.")
    result["modifiers"] = {key: calculate_modifier(stats.get(key, 10)) for key in catalog["abilities"]}
    result["proficiency_bonus"] = calculate_proficiency_bonus(level)
    result["save_bonuses"] = {key: calculate_check_bonus(stats.get(key, 10), level, result.get("saves", {}).get(key) is True)
                            for key in catalog["abilities"]}
    result["skill_bonuses"] = {item["key"]: calculate_check_bonus(
        stats.get(item["ability"], 10), level, result.get("skills", {}).get(item["key"]) is True,
        item["key"] in result.get("expertise", [])) for item in catalog["skills"]}
    result["passive_perception"] = 10 + result["skill_bonuses"]["percepcion"]
    return result
