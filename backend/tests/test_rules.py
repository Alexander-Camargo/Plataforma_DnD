import pytest
from app.domain.rules import (
    calculate_modifier, calculate_proficiency_bonus, calculate_passive_perception, format_modifier,
)


@pytest.mark.parametrize("score,expected", [(1,-5),(8,-1),(10,0),(11,0),(15,2),(20,5),(30,10)])
def test_modifiers_round_down(score, expected):
    assert calculate_modifier(score) == expected


@pytest.mark.parametrize("level,expected", [(1,2),(4,2),(5,3),(8,3),(9,4),(12,4),(13,5),(16,5),(17,6),(20,6)])
def test_proficiency_boundaries(level, expected):
    assert calculate_proficiency_bonus(level) == expected


@pytest.mark.parametrize("wis,trained,level,expected", [(12,False,1,11),(12,True,1,13),(8,False,5,9),(12,True,5,14)])
def test_passive_perception(wis, trained, level, expected):
    assert calculate_passive_perception(wis, trained, level) == expected


@pytest.mark.parametrize("value,expected", [(-2,"-2"),(0,"+0"),(5,"+5")])
def test_modifier_display(value, expected):
    assert format_modifier(value) == expected

