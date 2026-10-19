/*
Archivo: dnd_rules.dart
Propósito: Constantes y funciones puras de reglas D&D 5e en el cliente (modificadores, competencia, dados de golpe, niveles de ASI, subclase y compra por puntos).
Creador: Joshua Pérez Bullen / Alexander Camargo
Modificaciones / Actualizaciones:
- 2026-10-12 [Joshua Pérez Bullen]: Reglas base de características, habilidades, clases, ASI y compra por puntos.
- 2026-10-18 [Alexander Camargo]: Normalización de slugs sin tildes y metadatos de nivel/etiqueta de subclase para Hito 3.1.
- 2026-10-18 [Alexander Camargo]: Inclusión de tabla oficial de experiencia 5e (xpThresholds) y función xpForLevel.
*/

/// Reglas de D&D 5e usadas por la creación y la subida de nivel.
/// Las claves de clase/raza son los nombres tal como se muestran en la UI.
class DndRules {
  static String formatModifier(int value) => value >= 0 ? "+$value" : "$value";

  static String _norm(String input) => input
      .toLowerCase()
      .trim()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');

  static const List<String> races = [
    'Humano',
    'Elfo',
    'Enano',
    'Mediano',
    'Dracónido',
    'Tiefling',
    'Semielfo',
    'Semiorco',
    'Gnomo',
  ];

  static const List<String> alignments = [
    'Legal Bueno',
    'Neutral Bueno',
    'Caótico Bueno',
    'Legal Neutral',
    'Verdadero Neutral',
    'Caótico Neutral',
    'Legal Malvado',
    'Neutral Malvado',
    'Caótico Malvado',
  ];

  static const Map<String, String> statNames = {
    'fue': 'Fuerza',
    'des': 'Destreza',
    'con': 'Constitución',
    'int': 'Inteligencia',
    'sab': 'Sabiduría',
    'car': 'Carisma',
  };

  /// Las 18 habilidades: clave -> (nombre, atributo).
  static const Map<String, SkillInfo> skills = {
    'acrobacias': SkillInfo('Acrobacias', 'des'),
    'trato_animales': SkillInfo('Trato con animales', 'sab'),
    'arcanos': SkillInfo('Arcanos', 'int'),
    'atletismo': SkillInfo('Atletismo', 'fue'),
    'engano': SkillInfo('Engaño', 'car'),
    'historia': SkillInfo('Historia', 'int'),
    'interpretacion': SkillInfo('Interpretación', 'car'),
    'intimidacion': SkillInfo('Intimidación', 'car'),
    'investigacion': SkillInfo('Investigación', 'int'),
    'juego_manos': SkillInfo('Juego de manos', 'des'),
    'medicina': SkillInfo('Medicina', 'sab'),
    'naturaleza': SkillInfo('Naturaleza', 'int'),
    'percepcion': SkillInfo('Percepción', 'sab'),
    'perspicacia': SkillInfo('Perspicacia', 'sab'),
    'persuasion': SkillInfo('Persuasión', 'car'),
    'religion': SkillInfo('Religión', 'int'),
    'sigilo': SkillInfo('Sigilo', 'des'),
    'supervivencia': SkillInfo('Supervivencia', 'sab'),
  };

  /// Bonificadores raciales (SRD 5.1).
  static const Map<String, Map<String, int>> racialBonuses = {
    'Humano': {'fue': 1, 'des': 1, 'con': 1, 'int': 1, 'sab': 1, 'car': 1},
    'Elfo': {'des': 2},
    'Enano': {'con': 2},
    'Mediano': {'des': 2},
    'Dracónido': {'fue': 2, 'car': 1},
    'Tiefling': {'car': 2, 'int': 1},
    'Semielfo': {'car': 2},
    'Semiorco': {'fue': 2, 'con': 1},
    'Gnomo': {'int': 2},
  };

  static const Set<String> slowRaces = {'Enano', 'Mediano', 'Gnomo'};

  static int speedFor(String race) => slowRaces.contains(race) ? 25 : 30;

  /// Dado de golpe, salvaciones competentes, equipo inicial y subclase por clase.
  static const Map<String, ClassInfo> classes = {
    'Bárbaro': ClassInfo(
      12,
      ['fue', 'con'],
      ['Gran Hacha', 'Jabalina x4', 'Paquete de explorador'],
      subclassLevel: 3,
      subclassLabel: 'Senda primaria',
    ),
    'Bardo': ClassInfo(
      8,
      ['des', 'car'],
      ['Armadura de Cuero', 'Laúd', 'Estoque', 'Daga'],
      subclassLevel: 3,
      subclassLabel: 'Colegio bárdico',
    ),
    'Brujo': ClassInfo(
      8,
      ['sab', 'car'],
      ['Armadura de Cuero', 'Arma Simple', 'Foco Arcano'],
      subclassLevel: 1,
      subclassLabel: 'Patrón de otro mundo',
    ),
    'Clérigo': ClassInfo(
      8,
      ['sab', 'car'],
      ['Maza', 'Cota de Escamas', 'Símbolo Sagrado', 'Escudo'],
      subclassLevel: 1,
      subclassLabel: 'Dominio divino',
    ),
    'Druida': ClassInfo(
      8,
      ['int', 'sab'],
      ['Escudo de Madera', 'Cimitarra', 'Armadura de Cuero'],
      subclassLevel: 2,
      subclassLabel: 'Círculo druídico',
    ),
    'Explorador': ClassInfo(
      10,
      ['fue', 'des'],
      ['Armadura de Escamas', 'Dos Espadas Cortas', 'Arco Largo'],
      subclassLevel: 3,
      subclassLabel: 'Arquetipo de explorador',
    ),
    'Guerrero': ClassInfo(
      10,
      ['fue', 'con'],
      ['Cota de Mallas', 'Espada Larga', 'Escudo', 'Ballesta Ligera'],
      subclassLevel: 3,
      subclassLabel: 'Arquetipo marcial',
    ),
    'Hechicero': ClassInfo(
      6,
      ['con', 'car'],
      ['Ballesta Ligera', 'Foco Arcano', 'Dagas x2'],
      subclassLevel: 1,
      subclassLabel: 'Origen de hechicería',
    ),
    'Mago': ClassInfo(
      6,
      ['int', 'sab'],
      ['Bastón', 'Libro de Conjuros', 'Foco Arcano', 'Túnica'],
      subclassLevel: 2,
      subclassLabel: 'Tradición arcana',
    ),
    'Monje': ClassInfo(
      8,
      ['fue', 'des'],
      ['Espada Corta', 'Paquete de Explorador', 'Dardos x10'],
      subclassLevel: 3,
      subclassLabel: 'Tradición monástica',
    ),
    'Paladín': ClassInfo(
      10,
      ['sab', 'car'],
      ['Espada Larga', 'Escudo', 'Cota de Mallas', 'Símbolo Sagrado'],
      subclassLevel: 3,
      subclassLabel: 'Juramento sagrado',
    ),
    'Pícaro': ClassInfo(
      8,
      ['des', 'int'],
      ['Estoque', 'Arco Corto', 'Armadura de Cuero', 'Herramientas de Ladrón'],
      subclassLevel: 3,
      subclassLabel: 'Arquetipo de pícaro',
    ),
  };

  /// Busca la clase por nombre sin importar mayúsculas ni tildes.
  static ClassInfo? classInfo(String name) {
    final key = _norm(name);
    for (final e in classes.entries) {
      if (_norm(e.key) == key) return e.value;
    }
    return null;
  }

  static String displayClass(String slug) {
    final key = _norm(slug);
    for (final name in classes.keys) {
      if (_norm(name) == key) return name;
    }
    return slug;
  }

  static int modifier(int score) => ((score - 10) / 2).floor();

  /// Bonificador de competencia según nivel (+2 a nivel 1-4, +3 a 5-8 ...).
  static int proficiencyBonus(int level) => ((level - 1) ~/ 4) + 2;

  /// Niveles con Mejora de Característica (ASI).
  static bool hasAsi(String classSlug, int level) {
    const base = {4, 8, 12, 16, 19};
    final c = _norm(classSlug);
    if (base.contains(level)) return true;
    if (c == 'guerrero' && (level == 6 || level == 14)) return true;
    if (c == 'picaro' && level == 10) return true;
    return false;
  }

  /// PG ganados al subir de nivel usando el valor promedio del dado de golpe.
  static int hpPerLevel(String classSlug, int conMod) {
    final die = classInfo(classSlug)?.hitDie ?? 8;
    final gain = (die ~/ 2) + 1 + conMod;
    return gain < 1 ? 1 : gain;
  }

  // ---- Compra de puntos (27 puntos) ----
  static const Map<int, int> pointCosts = {
    8: 0,
    9: 1,
    10: 2,
    11: 3,
    12: 4,
    13: 5,
    14: 7,
    15: 9
  };
  static const int pointBudget = 27;

  // ---- Tabla Oficial de Experiencia (D&D 5e) ----
  static const Map<int, int> xpThresholds = {
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
  };

  static int xpForLevel(int level) =>
      xpThresholds[level.clamp(1, 20)] ?? 355000;

  /// Estados que asigna el DM (clave API -> etiqueta).
  static const Map<String, String> statuses = {
    'alive': 'Vivo',
    'dead': 'Muerto',
    'undead': 'No muerto',
    'resurrected': 'Resucitado',
    'race_changed': 'Cambió de raza',
    'lost': 'Perdido',
  };
}

class ClassInfo {
  final int hitDie;
  final List<String> saves;
  final List<String> equipment;
  final int subclassLevel;
  final String subclassLabel;
  const ClassInfo(
    this.hitDie,
    this.saves,
    this.equipment, {
    this.subclassLevel = 3,
    this.subclassLabel = 'Subclase',
  });
}

class SkillInfo {
  final String name;
  final String attribute;
  const SkillInfo(this.name, this.attribute);
}

