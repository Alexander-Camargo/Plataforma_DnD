import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dnd_frontend/core/api/api_client.dart';
import 'package:dnd_frontend/providers/auth_provider.dart';
import 'package:dnd_frontend/providers/campaign_provider.dart';
import 'package:dnd_frontend/providers/character_provider.dart';

Map<String, dynamic> character(
        {String id = 'p1', String? campaign, int version = 1}) =>
    {
      'id': id,
      'name': 'Lina',
      'race': 'Humano',
      'class_slug': 'guerrero',
      'campaign_id': campaign,
      'version': version,
    };
Map<String, dynamic> campaign({String notes = ''}) => {
      'id': 'c1',
      'name': 'Frontera',
      'description': '',
      'dm_notes': notes,
      'join_code': 'ABC12345',
      'dm_id': 'u1',
    };
http.Response jsonResponse(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiClient.onUnauthorized = null;
  });
  tearDown(() => ApiClient.onUnauthorized = null);

  test('Auth inicial sin token termina de cargar y no hace solicitudes',
      () async {
    await http.runWithClient(() async {
      final provider = AuthProvider();
      await provider.init();
      expect(provider.isLoading, isFalse);
      expect(provider.isAuthenticated, isFalse);
      provider.dispose();
    },
        () => MockClient(
            (_) async => throw StateError('No debe consultar la API')));
  });
  test('Login guarda token, carga usuario y logout limpia la sesión', () async {
    await http.runWithClient(() async {
      final provider = AuthProvider();
      expect(await provider.login(' player ', 'Password123!'), isNull);
      expect(provider.currentUser!.username, 'player');
      expect(provider.isAuthenticated, isTrue);
      expect((await SharedPreferences.getInstance()).getString('access_token'),
          'token');
      await provider.logout();
      expect(provider.currentUser, isNull);
      expect((await SharedPreferences.getInstance()).getString('access_token'),
          isNull);
      provider.dispose();
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/login')) {
                expect(jsonDecode(request.body)['identifier'], 'player');
                return jsonResponse({'access_token': 'token'});
              }
              expect(request.headers['Authorization'], 'Bearer token');
              return jsonResponse({'id': 'u1', 'username': 'player'});
            }));
  });
  test('Registro envía datos y luego inicia sesión', () async {
    final paths = <String>[];
    await http.runWithClient(() async {
      final provider = AuthProvider();
      expect(
          await provider.register(
              ' player ', ' player@example.com ', 'Password123!'),
          isNull);
      expect(paths,
          ['/api/v1/auth/register', '/api/v1/auth/login', '/api/v1/auth/me']);
      provider.dispose();
    },
        () => MockClient((request) async {
              paths.add(request.url.path);
              if (request.url.path.endsWith('/register')) {
                expect(jsonDecode(request.body)['email'], 'player@example.com');
                return jsonResponse({'id': 'u1'}, 201);
              }
              if (request.url.path.endsWith('/login')) {
                return jsonResponse({'access_token': 'token'});
              }
              return jsonResponse({'id': 'u1', 'username': 'player'});
            }));
  });
  test('Login rechazado muestra error sin autenticar', () async {
    await http.runWithClient(() async {
      final provider = AuthProvider();
      expect(
          await provider.login('player', 'wrong'), 'Credenciales incorrectas');
      expect(provider.isAuthenticated, isFalse);
      provider.dispose();
    },
        () => MockClient((_) async =>
            jsonResponse({'detail': 'Credenciales incorrectas'}, 401)));
  });
  test('Init restaura usuario con token persistido', () async {
    SharedPreferences.setMockInitialValues({'access_token': 'token'});
    await http.runWithClient(() async {
      final provider = AuthProvider();
      await provider.init();
      expect(provider.isAuthenticated, isTrue);
      expect(provider.isLoading, isFalse);
      provider.dispose();
    },
        () => MockClient(
            (_) async => jsonResponse({'id': 'u1', 'username': 'player'})));
  });
  test('Personajes disponibles excluyen campañas activas y clear vacía datos',
      () async {
    await http.runWithClient(() async {
      final provider = CharacterProvider();
      await provider.fetchMyCharacters();
      expect(provider.myCharacters.length, 2);
      expect(provider.availableCharacters.map((item) => item.id), ['p1']);
      provider.clear();
      expect(provider.myCharacters, isEmpty);
      provider.dispose();
    },
        () => MockClient((_) async =>
            jsonResponse([character(), character(id: 'p2', campaign: 'c1')])));
  });
  test('Retirarse envía versión y sustituye el personaje recibido', () async {
    await http.runWithClient(() async {
      final provider = CharacterProvider();
      await provider.fetchMyCharacters();
      expect(await provider.leaveCampaign(provider.myCharacters.first), isTrue);
      expect(provider.availableCharacters.length, 1);
      expect(provider.myCharacters.first.version, 4);
      provider.dispose();
    },
        () => MockClient((request) async {
              if (request.method == 'GET') {
                return jsonResponse([character(campaign: 'c1', version: 3)]);
              }
              expect(jsonDecode(request.body),
                  {'leave_campaign': true, 'version': 3});
              return jsonResponse(character(version: 4));
            }));
  });
  for (final fails in [false, true]) {
    test(
        'Eliminar personaje conserva o actualiza lista según respuesta: $fails',
        () async {
      await http.runWithClient(() async {
        final provider = CharacterProvider();
        await provider.fetchMyCharacters();
        expect(await provider.deleteCharacter(provider.myCharacters.first),
            !fails);
        expect(provider.myCharacters.length, fails ? 1 : 0);
        expect(provider.lastError, fails ? 'Campaña activa' : isNull);
        provider.dispose();
      },
          () => MockClient((request) async {
                if (request.method == 'GET') return jsonResponse([character()]);
                expect(request.method, 'DELETE');
                return fails
                    ? jsonResponse({'detail': 'Campaña activa'}, 409)
                    : http.Response('', 204);
              }));
    });
  }
  test('Retirarse con versión antigua conserva lista y muestra conflicto',
      () async {
    await http.runWithClient(() async {
      final provider = CharacterProvider();
      await provider.fetchMyCharacters();
      expect(
          await provider.leaveCampaign(provider.myCharacters.first), isFalse);
      expect(provider.myCharacters.first.campaignId, 'c1');
      expect(provider.lastError, 'Recarga');
      provider.dispose();
    },
        () => MockClient((request) async => request.method == 'GET'
            ? jsonResponse([character(campaign: 'c1')])
            : jsonResponse({'detail': 'Recarga'}, 409)));
  });
  test('Crear y unirse no duplica campañas; actualizar notas cambia la lista',
      () async {
    await http.runWithClient(() async {
      final provider = CampaignProvider();
      expect(await provider.createCampaign('Frontera', ''), isNotNull);
      expect(await provider.joinCampaign('ABC12345', 'p1'), isNotNull);
      expect(provider.campaigns.length, 1);
      expect(await provider.updateCampaignNotes('c1', 'Secreto'), isTrue);
      expect(provider.campaigns.first.dmNotes, 'Secreto');
      provider.clear();
      expect(provider.campaigns, isEmpty);
      provider.dispose();
    },
        () => MockClient((request) async {
              if (request.method == 'PATCH') {
                expect(jsonDecode(request.body), {'dm_notes': 'Secreto'});
                return jsonResponse(campaign(notes: 'Secreto'));
              }
              if (request.url.path.endsWith('/join')) {
                expect(jsonDecode(request.body),
                    {'join_code': 'ABC12345', 'character_id': 'p1'});
              }
              return jsonResponse(campaign());
            }));
  });
  test('Errores de campañas devuelven fallo y no inventan elementos', () async {
    await http.runWithClient(() async {
      final provider = CampaignProvider();
      expect(await provider.createCampaign('Frontera', ''), isNull);
      expect(await provider.joinCampaign('bad', 'p1'), isNull);
      expect(await provider.updateCampaignNotes('c1', 'Nota'), isFalse);
      expect(provider.lastError, 'Sin permiso');
      expect(provider.campaigns, isEmpty);
      provider.dispose();
    },
        () => MockClient(
            (_) async => jsonResponse({'detail': 'Sin permiso'}, 403)));
  });
  test('Carga notifica inicio y fin incluso con fallo de red', () async {
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    await http.runWithClient(() async {
      final provider = CampaignProvider();
      final states = <bool>[];
      provider.addListener(() => states.add(provider.isLoading));
      final fetching = provider.fetchMyCampaigns();
      expect(provider.isLoading, isTrue);
      await started.future;
      pending.completeError(http.ClientException('offline'));
      await fetching;
      expect(states, [true, false]);
      expect(provider.isLoading, isFalse);
      provider.dispose();
    },
        () => MockClient((_) {
              started.complete();
              return pending.future;
            }));
  });
}
