/// Reglas de D&D 5e usadas por la creación y la subida de nivel.
/// Las claves de clase/raza son los nombres tal como se muestran en la UI.
class DndRules {
  static String formatModifier(int value) => value >= 0 ? "+$value" : "$value";
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

  /// Dado de golpe, salvaciones competentes y equipo inicial por clase.
  static const Map<String, ClassInfo> classes = {
    'Bárbaro': ClassInfo(12, ['fue', 'con'],
        ['Gran Hacha', 'Jabalina x4', 'Paquete de explorador']),
    'Bardo': ClassInfo(
        8, ['des', 'car'], ['Armadura de Cuero', 'Laúd', 'Estoque', 'Daga']),
    'Brujo': ClassInfo(
        8, ['sab', 'car'], ['Armadura de Cuero', 'Arma Simple', 'Foco Arcano']),
    'Clérigo': ClassInfo(8, ['sab', 'car'],
        ['Maza', 'Cota de Escamas', 'Símbolo Sagrado', 'Escudo']),
    'Druida': ClassInfo(8, ['int', 'sab'],
        ['Escudo de Madera', 'Cimitarra', 'Armadura de Cuero']),
    'Explorador': ClassInfo(10, ['fue', 'des'],
        ['Armadura de Escamas', 'Dos Espadas Cortas', 'Arco Largo']),
    'Guerrero': ClassInfo(10, ['fue', 'con'],
        ['Cota de Mallas', 'Espada Larga', 'Escudo', 'Ballesta Ligera']),
    'Hechicero': ClassInfo(
        6, ['con', 'car'], ['Ballesta Ligera', 'Foco Arcano', 'Dagas x2']),
    'Mago': ClassInfo(6, ['int', 'sab'],
        ['Bastón', 'Libro de Conjuros', 'Foco Arcano', 'Túnica']),
    'Monje': ClassInfo(8, ['fue', 'des'],
        ['Espada Corta', 'Paquete de Explorador', 'Dardos x10']),
    'Paladín': ClassInfo(10, ['sab', 'car'],
        ['Espada Larga', 'Escudo', 'Cota de Mallas', 'Símbolo Sagrado']),
    'Pícaro': ClassInfo(8, [
      'des',
      'int'
    ], [
      'Estoque',
      'Arco Corto',
      'Armadura de Cuero',
      'Herramientas de Ladrón'
    ]),
  };

  /// Busca la clase por nombre sin importar mayúsculas (el backend guarda el slug en minúsculas).
  static ClassInfo? classInfo(String name) {
    final key = name.toLowerCase();
    for (final e in classes.entries) {
      if (e.key.toLowerCase() == key) return e.value;
    }
    return null;
  }

  static String displayClass(String slug) {
    final key = slug.toLowerCase();
    for (final name in classes.keys) {
      if (name.toLowerCase() == key) return name;
    }
    return slug;
  }

  static int modifier(int score) => ((score - 10) / 2).floor();

  /// Bonificador de competencia según nivel (+2 a nivel 1-4, +3 a 5-8 ...).
  static int proficiencyBonus(int level) => ((level - 1) ~/ 4) + 2;

  /// Niveles con Mejora de Característica (ASI).
  static bool hasAsi(String classSlug, int level) {
    const base = {4, 8, 12, 16, 19};
    final c = classSlug.toLowerCase();
    if (base.contains(level)) return true;
    if (c == 'guerrero' && (level == 6 || level == 14)) return true;
    if (c == 'pícaro' && level == 10) return true;
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
  const ClassInfo(this.hitDie, this.saves, this.equipment);
}

class SkillInfo {
  final String name;
  final String attribute;
  const SkillInfo(this.name, this.attribute);
}
