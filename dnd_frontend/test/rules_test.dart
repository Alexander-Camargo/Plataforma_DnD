import 'package:flutter_test/flutter_test.dart';
import 'package:dnd_frontend/core/data/dnd_rules.dart';

void main() {
  for (final entry
      in {1: -5, 8: -1, 10: 0, 11: 0, 15: 2, 20: 5, 30: 10}.entries) {
    test('Modificador de ${entry.key} redondea hacia abajo', () {
      expect(DndRules.modifier(entry.key), entry.value);
    });
  }
  for (final entry in {
    1: 2,
    4: 2,
    5: 3,
    8: 3,
    9: 4,
    12: 4,
    13: 5,
    16: 5,
    17: 6,
    20: 6
  }.entries) {
    test('Competencia en nivel ${entry.key}', () {
      expect(DndRules.proficiencyBonus(entry.key), entry.value);
    });
  }
  test('Mejora de característica respeta excepciones de clase', () {
    expect(DndRules.hasAsi('guerrero', 6), isTrue);
    expect(DndRules.hasAsi('Guerrero', 14), isTrue);
    expect(DndRules.hasAsi('pícaro', 10), isTrue);
    expect(DndRules.hasAsi('mago', 6), isFalse);
    for (final level in [4, 8, 12, 16, 19]) {
      expect(DndRules.hasAsi('mago', level), isTrue);
    }
  });
  test('PG al subir de nivel usan promedio y mínimo de uno', () {
    expect(DndRules.hpPerLevel('guerrero', 2), 8);
    expect(DndRules.hpPerLevel('mago', 1), 5);
    expect(DndRules.hpPerLevel('mago', -5), 1);
  });
  test('Compra de puntos de referencia consume exactamente 27', () {
    final scores = [15, 15, 15, 8, 8, 8];
    expect(
        scores.fold<int>(0, (sum, value) => sum + DndRules.pointCosts[value]!),
        DndRules.pointBudget);
    expect(DndRules.pointCosts[14], 7);
  });
  test('Nombres de clase se resuelven sin importar mayúsculas', () {
    expect(DndRules.classInfo('GUERRERO')!.hitDie, 10);
    expect(DndRules.displayClass('mago'), 'Mago');
    expect(DndRules.classInfo('desconocida'), isNull);
    expect(DndRules.displayClass('desconocida'), 'desconocida');
  });
  test('Velocidades de razas pequeñas y enanos', () {
    for (final race in ['Enano', 'Mediano', 'Gnomo']) {
      expect(DndRules.speedFor(race), 25);
    }
    expect(DndRules.speedFor('Humano'), 30);
  });
}
