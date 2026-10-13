class CreationCatalog {
  final List<Map<String, dynamic>> races, classes, backgrounds, skills;
  final List<String> abilities;
  final Map<int, int> pointCosts;
  final Map<String, String> toolLabels;
  final int pointBudget, baseMin, baseMax;
  const CreationCatalog({
    required this.races,
    required this.classes,
    required this.backgrounds,
    required this.skills,
    required this.abilities,
    required this.pointCosts,
    required this.pointBudget,
    required this.baseMin,
    required this.baseMax,
    required this.toolLabels,
  });
  factory CreationCatalog.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> entries(String key) => (json[key] as List)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    return CreationCatalog(
      races: entries('races'),
      classes: entries('classes'),
      backgrounds: entries('backgrounds'),
      skills: entries('skills'),
      abilities: List<String>.from(json['abilities']),
      pointCosts: (json['point_costs'] as Map).map(
          (key, value) => MapEntry(int.parse(key.toString()), value as int)),
      pointBudget: json['point_budget'],
      baseMin: json['base_min'],
      baseMax: json['base_max'],
      toolLabels: Map<String, String>.from(json['tool_labels']),
    );
  }
}
