import 'package:flutter_test/flutter_test.dart';
import 'package:dnd_frontend/models/models.dart';
import 'package:dnd_frontend/core/data/dnd_rules.dart';

Character hero(int level, Map<String, dynamic> sheet) => Character.fromJson({
      'id': 'x',
      'name': 'Lina',
      'race': 'Humano',
      'class_slug': 'pícaro',
      'level': level,
      'sheet': sheet,
    });

void main() {
  test(
      'La competencia se suma una vez y la pericia duplica solo la competencia',
      () {
    final character = hero(5, {
      'stats': {'des': 14},
      'modifiers': {'des': 99},
      'skills': {'sigilo': true, 'acrobacias': true},
      'expertise': ['sigilo'],
      'saves': {'des': true}
    });
    expect(character.skillBonus('sigilo'), 8);
    expect(character.skillBonus('acrobacias'), 5);
    expect(character.skillBonus('juego_manos'), 2);
    expect(character.savingThrowBonus('des'), 5);
  });
  test('Una hoja antigua conserva sus puntuaciones y competencias', () {
    final character = hero(1, {
      'stats': {'fue': 9},
      'skills': {'atletismo': true}
    });
    expect(character.skillBonus('atletismo'), 1);
    expect(character.savingThrowBonus('fue'), -1);
    expect(character.sheet['stats']['fue'], 9);
  });
  test('La pericia sin competencia no añade un bonificador', () {
    expect(
        hero(1, {
          'stats': {'des': 14},
          'expertise': ['sigilo']
        }).skillBonus('sigilo'),
        2);
  });
  test(
      'Todas las habilidades pueden mostrarse sin datos de creación históricos',
      () {
    final character = hero(1, {});
    for (final key in DndRules.skills.keys) {
      expect(character.skillBonus(key), 0);
    }
    expect(DndRules.skills.length, 18);
  });
}
