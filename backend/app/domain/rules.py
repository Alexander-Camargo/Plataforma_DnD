"""Reglas puras de D&D 5e: modificadores, bonificador de competencia, etc."""
import math

def calculate_modifier(score: int) -> int:
    """Calcula el modificador a partir de una puntuación de característica."""
    return math.floor((score - 10) / 2)

def calculate_proficiency_bonus(level: int) -> int:
    """Calcula el bonificador de competencia según el nivel del personaje."""
    return math.ceil(level / 4) + 1

def format_modifier(mod: int) -> str:
    """Formatea un modificador como cadena, ej: '+2', '-1', '+0'."""
    return f"+{mod}" if mod >= 0 else str(mod)

def calculate_passive_perception(wis_score: int, has_proficiency: bool, level: int) -> int:
    base = 10 + calculate_modifier(wis_score)
    if has_proficiency:
        base += calculate_proficiency_bonus(level)
    return base
