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

class Character {
  final String id;
  final String? ownerId;
  final String? campaignId;
  final String name;
  final String race;
  final String classSlug;
  final int level;
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
    this.avatarUrl,
    required this.status,
    required this.statusNote,
    required this.sheet,
    required this.version,
  });

  bool get inCampaign => campaignId != null;

  /// Campañas terminadas (se guardan en la hoja al retirar al personaje).
  List<Map<String, dynamic>> get campaignHistory {
    final raw = sheet['campaign_history'];
    if (raw is! List) return [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
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
      avatarUrl: json['avatar_url'],
      status: json['status'] ?? 'alive',
      statusNote: json['status_note'] ?? '',
      sheet: Map<String, dynamic>.from(json['sheet'] ?? {}),
      version: json['version'] ?? 1,
    );
  }
}
