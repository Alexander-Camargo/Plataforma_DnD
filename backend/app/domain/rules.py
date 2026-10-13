"""Reglas puras de D&D 5e (2014), sin acceso a DB ni a HTTP."""
import math
from copy import deepcopy


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
    sheet["creation"] = {**deepcopy(choices), "edition": catalog["edition"],
                         "race_id": race["id"], "class_id": cls["id"],
                         "subrace_id": subrace["id"] if subrace else None, "point_cost": spent}
    sheet["background"] = {**sheet.get("background", {}), "id": background["id"], "name": background["name"]}
    return sheet


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
