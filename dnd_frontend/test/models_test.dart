import 'package:flutter_test/flutter_test.dart';
import 'package:dnd_frontend/models/models.dart';

void main() {
  test('Usuario interpreta la respuesta del servidor', () {
    final user = User.fromJson({'id': 'u1', 'username': 'Lina'});
    expect(user.id, 'u1');
    expect(user.username, 'Lina');
  });
  test('Campaña conserva DM, código y notas opcionales', () {
    final campaign = Campaign.fromJson({
      'id': 'c1',
      'name': 'Frontera',
      'join_code': 'ABC12345',
      'dm_id': 'u1'
    });
    expect(campaign.dmId, 'u1');
    expect(campaign.joinCode, 'ABC12345');
    expect(campaign.dmNotes, '');
    expect(campaign.description, '');
  });
  test('Personaje aplica valores por defecto sin perder la hoja', () {
    final character = Character.fromJson({
      'id': 'p1',
      'name': 'Lina',
      'race': 'Humano',
      'class_slug': 'guerrero',
      'sheet': {
        'stats': {'fue': 14},
        'equipment': ['Cuerda']
      }
    });
    expect(character.level, 1);
    expect(character.version, 1);
    expect(character.status, 'alive');
    expect(character.inCampaign, isFalse);
    expect(character.sheet['equipment'], ['Cuerda']);
  });
  test('Vínculo de campaña y bloqueo optimista se leen de la API', () {
    final character = Character.fromJson({
      'id': 'p1',
      'owner_id': 'u1',
      'campaign_id': 'c1',
      'name': 'Lina',
      'race': 'Humano',
      'class_slug': 'guerrero',
      'version': 4,
      'level': 3,
      'status': 'lost'
    });
    expect(character.inCampaign, isTrue);
    expect(character.ownerId, 'u1');
    expect(character.version, 4);
    expect(character.status, 'lost');
  });
  test('Historial de campañas filtra elementos inválidos', () {
    final character = Character.fromJson({
      'id': 'p1',
      'name': 'Lina',
      'race': 'Humano',
      'class_slug': 'guerrero',
      'sheet': {
        'campaign_history': [
          {'id': 'c1', 'name': 'Frontera'},
          'invalid',
          null
        ]
      }
    });
    expect(character.campaignHistory, [
      {'id': 'c1', 'name': 'Frontera'}
    ]);
  });
  test('Historial ausente o de tipo incorrecto queda vacío', () {
    final character = Character.fromJson({
      'id': 'p1',
      'name': 'Lina',
      'race': 'Humano',
      'class_slug': 'guerrero',
      'sheet': {'campaign_history': 'invalid'}
    });
    expect(character.campaignHistory, isEmpty);
  });
}
