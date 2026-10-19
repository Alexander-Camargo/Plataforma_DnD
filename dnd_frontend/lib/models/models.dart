/*
Archivo: models.dart
Propósito: Modelos de datos para el frontend (User, Campaign, Character con experiencia y Milestone/Hitos de campaña).
Creador: Alexander Camargo / Joshua Pérez Bullen
Modificaciones / Actualizaciones:
- 2026-10-08 [Alexander Camargo]: Modelos User, Campaign y Character base.
- 2026-10-12 [Joshua Pérez Bullen]: Cálculo de bonos de salvación, habilidades y pericia en Character.
- 2026-10-18 [Alexander Camargo]: Inclusión del campo experience (XP) en Character y modelo Milestone para hitos de campaña.
*/

import '../core/data/dnd_rules.dart';

class User {
  final String id;
  final String username;

  User({required this.id, required this.username});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
    );
  }
}

class Campaign {
  final String id;
  final String name;
  final String description;
  final String dmNotes;
  final String joinCode;
  final String dmId;

  Campaign({
    required this.id,
    required this.name,
    required this.description,
    required this.dmNotes,
    required this.joinCode,
    required this.dmId,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      dmNotes: json['dm_notes'] ?? '',
      joinCode: json['join_code'],
      dmId: json['dm_id'],
    );
  }
}

class Milestone {
  final String id;
  final String campaignId;
  final String title;
  final String description;
  final int targetLevel;
  final int xpGranted;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;

  Milestone({
    required this.id,
    required this.campaignId,
    required this.title,
    required this.description,
    required this.targetLevel,
    required this.xpGranted,
    required this.isCompleted,
    this.completedAt,
    required this.createdAt,
  });

  factory Milestone.fromJson(Map<String, dynamic> json) {
    return Milestone(
      id: json['id'],
      campaignId: json['campaign_id'],
      title: json['title'],
      description: json['description'] ?? '',
      targetLevel: json['target_level'] ?? 2,
      xpGranted: json['xp_granted'] ?? 0,
      isCompleted: json['is_completed'] ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class Character {
  final String id;
  final String? ownerId;
  final String? campaignId;
  final String name;
  final String race;
  final String classSlug;
  final int level;
  final int experience;
  final String? avatarUrl;
  final String status;
  final String statusNote;
  final Map<String, dynamic> sheet;
  final int version;

  Character({
    required this.id,
    this.ownerId,
    this.campaignId,
    required this.name,
    required this.race,
    required this.classSlug,
    required this.level,
    this.experience = 0,
    this.avatarUrl,
    required this.status,
    required this.statusNote,
    required this.sheet,
    required this.version,
  });

  int _abilityModifier(String ability) {
    final score = (sheet['stats'] as Map?)?[ability];
    if (score is num) return ((score.toInt() - 10) / 2).floor();
    return ((sheet['modifiers'] as Map?)?[ability] as num?)?.toInt() ?? 0;
  }

  int get proficiencyBonus => DndRules.proficiencyBonus(level);
  bool isSaveProficient(String ability) =>
      (sheet['saves'] as Map?)?[ability] == true;
  bool isSkillProficient(String skill) =>
      (sheet['skills'] as Map?)?[skill] == true;
  bool hasExpertise(String skill) =>
      (sheet['expertise'] as List?)?.contains(skill) ?? false;
  int savingThrowBonus(String ability) =>
      _abilityModifier(ability) +
      (isSaveProficient(ability) ? proficiencyBonus : 0);
  int skillBonus(String skill) =>
      _abilityModifier(DndRules.skills[skill]!.attribute) +
      (isSkillProficient(skill)
          ? proficiencyBonus * (hasExpertise(skill) ? 2 : 1)
          : 0);

  bool get inCampaign => campaignId != null;

  /// Campañas terminadas (se guardan en la hoja al retirar al personaje).
  List<Map<String, dynamic>> get campaignHistory {
    final raw = sheet['campaign_history'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      id: json['id'],
      ownerId: json['owner_id'],
      campaignId: json['campaign_id'],
      name: json['name'],
      race: json['race'],
      classSlug: json['class_slug'],
      level: json['level'] ?? 1,
      experience: (json['experience'] as num?)?.toInt() ?? 0,
      avatarUrl: json['avatar_url'],
      status: json['status'] ?? 'alive',
      statusNote: json['status_note'] ?? '',
      sheet: Map<String, dynamic>.from(json['sheet'] ?? {}),
      version: json['version'] ?? 1,
    );
  }
}

