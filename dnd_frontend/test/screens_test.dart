/*
Archivo: screens_test.dart
Propósito: Pruebas de integración de widgets para las pantallas principales (campañas, mesa del DM, hoja de personaje, subida de nivel y rasgos).
Creador: Joshua Pérez Bullen / Alexander Camargo
Modificaciones / Actualizaciones:
- 2026-10-12 [Joshua Pérez Bullen]: Pruebas de flujo de campañas, combate, edición de hoja y eliminación de personaje.
- 2026-10-18 [Alexander Camargo]: Pruebas del diálogo de subida de nivel 5e (Hito 3.1) y visualización dinámica de rasgos.
*/

import 'fixtures/creation_catalog.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dnd_frontend/core/router/app_router.dart';
import 'package:dnd_frontend/core/theme/app_theme.dart';
import 'package:dnd_frontend/models/models.dart';
import 'package:dnd_frontend/providers/auth_provider.dart';
import 'package:dnd_frontend/providers/campaign_provider.dart';
import 'package:dnd_frontend/providers/character_provider.dart';
import 'package:dnd_frontend/widgets/network_avatar.dart';

class _Auth extends AuthProvider {
  final String userId;
  _Auth(this.userId);
  @override
  bool get isAuthenticated => true;
  @override
  bool get isLoading => false;
  @override
  User get currentUser => User(id: userId, username: 'Aventurero');
}

Map<String, dynamic> campaign({String dm = 'u1'}) => {
      'id': 'c1',
      'name': 'La frontera',
      'description': 'Una aventura',
      'dm_notes': dm == 'u1' ? 'Pista secreta' : '',
      'join_code': 'ABCD1234',
      'dm_id': dm,
    };
Map<String, dynamic> hero({String? campaignId = 'c1', int experience = 300}) => {
      'id': 'p1',
      'owner_id': 'u2',
      'campaign_id': campaignId,
      'name': 'Lina',
      'race': 'Humano',
      'class_slug': 'guerrero',
      'level': 1,
      'status': 'alive',
      'version': 3,
      'status_note': '',
      'experience': experience,
      'sheet': {
        'hp': 12,
        'ac': 15,
        'speed': 30,
        'stats': {
          'fue': 14,
          'des': 12,
          'con': 14,
          'int': 10,
          'sab': 10,
          'car': 8
        },
        'modifiers': {
          'fue': 2,
          'des': 1,
          'con': 2,
          'int': 0,
          'sab': 0,
          'car': -1
        },
        'saves': {'fue': true, 'con': true},
        'equipment': ['Cuerda'],
        'background': {'history': 'Una marinera', 'ideals': 'Ayudar'},
      },
    };
http.Response reply(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

class _AppSession {
  final _Auth auth;
  final CampaignProvider campaigns = CampaignProvider();
  final CharacterProvider characters = CharacterProvider();
  late final GoRouter router =
      AppRouter.createRouter(auth, creationCatalog: testCatalog());
  _AppSession(String user) : auth = _Auth(user);
  Future<void> mount(WidgetTester tester, String path) async {
    router.go(path);
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<CampaignProvider>.value(value: campaigns),
      ChangeNotifierProvider<CharacterProvider>.value(value: characters),
    ], child: MaterialApp.router(theme: AppTheme.light, routerConfig: router)));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    auth.dispose();
    campaigns.dispose();
    characters.dispose();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final requests = <http.Request>[];
  Future<http.Response> normal(http.Request request) async {
    requests.add(request);
    if (request.url.path == '/api/v1/campaigns/') return reply([campaign()]);
    if (request.url.path == '/api/v1/characters/me') return reply([hero()]);
    if (request.url.path == '/api/v1/characters/') return reply([hero()]);
    if (request.url.path == '/api/v1/characters/p1') return reply(hero());
    if (request.url.path.contains('/milestones')) return reply([]);
    return reply({'detail': 'No encontrado'}, 404);
  }

  setUp(requests.clear);

  testWidgets('Campañas muestra la mesa y permite entrar como DM',
      (tester) async {
    await http.runWithClient(() async {
      final app = _AppSession('u1');
      await app.mount(tester, '/');
      expect(find.text('La frontera'), findsOneWidget);
      await tester.tap(find.text('La frontera'));
      await tester.pumpAndSettle();
      expect(find.text('Iniciativa y Combate'), findsOneWidget);
      await app.close(tester);
    }, () => MockClient(normal));
  });

  testWidgets('Crear campaña valida nombre y muestra el código recibido',
      (tester) async {
    await http.runWithClient(() async {
      final app = _AppSession('u1');
      await app.mount(tester, '/');
      await tester.tap(find.text('Crear campaña'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear'));
      await tester.pump();
      expect(find.text('El nombre es obligatorio'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Nueva aventura');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear'));
      await tester.pumpAndSettle();
      expect(find.text('¡Campaña creada!'), findsOneWidget);
      expect(find.text('ABCD1234'), findsOneWidget);
      await app.close(tester);
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                expect(jsonDecode(request.body)['name'], 'Nueva aventura');
                return reply(campaign(), 201);
              }
              return normal(request);
            }));
  });

  testWidgets('Unirse sin personajes libres explica el requisito',
      (tester) async {
    await http.runWithClient(() async {
      final app = _AppSession('u2');
      await app.mount(tester, '/');
      await tester.tap(find.text('Unirse'));
      await tester.pumpAndSettle();
      expect(
          find.text(
              'No tienes personajes libres. Crea uno nuevo o termina la campaña de otro.'),
          findsOneWidget);
      await app.close(tester);
    }, () => MockClient(normal));
  });

  testWidgets('Jugador ve el grupo sin pestañas ni notas del DM',
      (tester) async {
    await http.runWithClient(() async {
      final app = _AppSession('u2');
      await app.mount(tester, '/campaign/c1');
      expect(find.text('Lina'), findsOneWidget);
      expect(find.text('Una aventura'), findsOneWidget);
      expect(find.text('Iniciativa y Combate'), findsNothing);
      expect(find.text('Notas Ocultas'), findsNothing);
      await app.close(tester);
    }, () => MockClient(normal));
  });

  testWidgets('DM edita y guarda notas de campaña', (tester) async {
    await http.runWithClient(() async {
      final app = _AppSession('u1');
      await app.mount(tester, '/campaign/c1');
      await tester.tap(find.text('Notas Ocultas'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Nueva pista');
      await tester.tap(find.text('Guardar notas'));
      await tester.pumpAndSettle();
      expect(find.text('Notas guardadas.'), findsOneWidget);
      await app.close(tester);
    },
        () => MockClient((request) async {
              if (request.method == 'PATCH') {
                expect(request.url.path, '/api/v1/campaigns/c1');
                expect(jsonDecode(request.body), {'dm_notes': 'Nueva pista'});
                return reply({...campaign(), 'dm_notes': 'Nueva pista'});
              }
              return normal(request);
            }));
  });

  testWidgets('DM cambia estado con nota y actualiza la lista', (tester) async {
    await http.runWithClient(() async {
      final app = _AppSession('u1');
      await app.mount(tester, '/campaign/c1');
      await tester.tap(find.byTooltip('Cambiar estado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perdido'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Portal');
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(find.text('PERDIDO'), findsOneWidget);
      expect(find.textContaining('Portal'), findsOneWidget);
      await app.close(tester);
    },
        () => MockClient((request) async {
              if (request.method == 'PATCH') {
                expect(request.url.path, '/api/v1/characters/p1/status');
                expect(jsonDecode(request.body),
                    {'status': 'lost', 'status_note': 'Portal'});
                return reply({
                  ...hero(),
                  'status': 'lost',
                  'status_note': 'Portal',
                  'version': 4
                });
              }
              return normal(request);
            }));
  });

  testWidgets('Combate ajusta PG locales y Reiniciar los restaura',
      (tester) async {
    await http.runWithClient(() async {
      final app = _AppSession('u1');
      await app.mount(tester, '/campaign/c1');
      await tester.tap(find.text('Iniciativa y Combate'));
      await tester.pumpAndSettle();
      expect(find.text('12/12'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.remove_circle));
      await tester.pump();
      expect(find.text('11/12'), findsOneWidget);
      await tester.tap(find.text('Reiniciar'));
      await tester.pumpAndSettle();
      expect(find.text('12/12'), findsOneWidget);
      expect(requests.where((request) => request.method == 'PATCH'), isEmpty);
      await app.close(tester);
    }, () => MockClient(normal));
  });

  testWidgets('Dashboard DM permite entrar a su mesa', (tester) async {
    await http.runWithClient(() async {
      final app = _AppSession('u1');
      await app.mount(tester, '/dm-dashboard');
      await tester.tap(find.text('La frontera'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entrar a la mesa de campaña'));
      await tester.pumpAndSettle();
      expect(find.text('Control de Personajes'), findsOneWidget);
      await app.close(tester);
    }, () => MockClient(normal));
  });

  for (final conflict in [false, true]) {
    testWidgets('Guardar hoja envía versión y gestiona conflicto: $conflict',
        (tester) async {
      await http.runWithClient(() async {
        final app = _AppSession('u2');
        await app.mount(tester, '/character/p1');
        await tester.tap(find.text('Editar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();
        expect(
            find.text(conflict
                ? 'Error al guardar: Recarga la hoja'
                : 'Cambios guardados con éxito.'),
            findsOneWidget);
        if (conflict) expect(find.text('Guardar'), findsOneWidget);
        await app.close(tester);
      },
          () => MockClient((request) async {
                if (request.method == 'PATCH') {
                  final body = jsonDecode(request.body);
                  expect(body['version'], 3);
                  expect(body['sheet']['equipment'], ['Cuerda']);
                  return conflict
                      ? reply({'detail': 'Recarga la hoja'}, 409)
                      : reply(
                          {...hero(), 'version': 4, 'sheet': body['sheet']});
                }
                return normal(request);
              }));
    });
  }

  testWidgets('Pestañas de hoja muestran trasfondo y equipo', (tester) async {
    await http.runWithClient(() async {
      final app = _AppSession('u2');
      await app.mount(tester, '/character/p1');
      await tester.tap(find.text('Trasfondo'));
      await tester.pumpAndSettle();
      expect(find.text('Una marinera'), findsOneWidget);
      await tester.ensureVisible(find.text('Equipo'));
      await tester.tap(find.text('Equipo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cuerda'), findsOneWidget);
      await app.close(tester);
    }, () => MockClient(normal));
  });

  testWidgets('Eliminar personaje requiere confirmar y actualiza la lista',
      (tester) async {
    await http.runWithClient(() async {
      final app = _AppSession('u2');
      await app.mount(tester, '/my-characters');
      await tester.tap(find.text('Lina'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Eliminar'));
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();
      expect(requests.where((request) => request.method == 'DELETE'), isEmpty);
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('Personaje eliminado.'), findsOneWidget);
      expect(find.text('Lina'), findsNothing);
      await app.close(tester);
    },
        () => MockClient((request) async {
              requests.add(request);
              if (request.method == 'DELETE') return http.Response('', 204);
              if (request.url.path.endsWith('/characters/me')) {
                return reply([hero(campaignId: null)]);
              }
              return normal(request);
            }));
  });

  testWidgets('Error de campaña se muestra sin fallar la pantalla',
      (tester) async {
    await http.runWithClient(() async {
      final app = _AppSession('u2');
      await app.mount(tester, '/campaign/c1');
      expect(find.text('Sin permiso'), findsOneWidget);
      await app.close(tester);
    }, () => MockClient((_) async => reply({'detail': 'Sin permiso'}, 403)));
  });

  testWidgets('Avatar vacío usa el marcador sin hacer solicitudes',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: NetworkAvatar(
                url: ' ',
                width: 80,
                height: 80,
                placeholder: Text('Sin imagen')))));
    expect(find.text('Sin imagen'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('Subir nivel abre diálogo 5e, actualiza nivel y muestra rasgos',
      (tester) async {
    await http.runWithClient(() async {
      final app = _AppSession('u2');
      await app.mount(tester, '/character/p1');
      await tester.tap(find.text('Subir Nivel'));
      await tester.pumpAndSettle();
      expect(find.text('Subir a Nivel 2'), findsOneWidget);
      expect(find.textContaining('PG Máximos: 12 → 20'), findsOneWidget);

      await tester.tap(find.text('Confirmar Subida'));
      await tester.pumpAndSettle();
      expect(
          find.text('¡Felicidades! Has alcanzado el nivel 2.'), findsOneWidget);
      expect(find.text('Humano GUERRERO - Nivel 2'), findsOneWidget);

      await tester.ensureVisible(find.text('Rasgos'));
      await tester.tap(find.text('Rasgos'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Acción súbita'), findsOneWidget);
      await app.close(tester);
    },
        () => MockClient((request) async {
              if (request.method == 'PATCH' &&
                  request.url.path == '/api/v1/characters/p1') {
                final body = jsonDecode(request.body);
                expect(body['level'], 2);
                expect(body['version'], 3);
                final updatedSheet = Map<String, dynamic>.from(hero()['sheet']);
                updatedSheet['hp'] = 20;
                updatedSheet['features'] = [
                  {
                    'name': 'Acción súbita',
                    'source': 'Guerrero',
                    'level': 2,
                    'description':
                        'Una vez por descanso corto, realizas una acción adicional.'
                  }
                ];
                return reply({
                  ...hero(),
                  'level': 2,
                  'version': 4,
                  'sheet': updatedSheet,
                });
              }
              return normal(request);
            }));
  });

  testWidgets(
      'Control de Personajes muestra XP y DM puede consultar pestaña de Hitos',
      (tester) async {
    await http.runWithClient(() async {
      final app = _AppSession('u1');
      await app.mount(tester, '/campaign/c1');
      expect(find.text('Control de Personajes'), findsOneWidget);
      expect(find.textContaining('⭐ 300 / 300 XP'), findsOneWidget);

      await tester.tap(find.text('Hitos'));
      await tester.pumpAndSettle();
      expect(find.text('No se han definido hitos para esta campaña.\nLos hitos permiten avanzar de nivel y otorgar XP.'), findsOneWidget);
      expect(find.text('Crear Hito'), findsOneWidget);
      await app.close(tester);
    }, () => MockClient(normal));
  });

  testWidgets(
      'Personaje sin campaña activa o sin XP suficiente bloquea subida de nivel',
      (tester) async {
    await http.runWithClient(() async {
      // Caso 1: Sin campaña activa
      final app1 = _AppSession('u2');
      await app1.mount(tester, '/character/p1');
      await tester.tap(find.text('Subir Nivel'));
      await tester.pumpAndSettle();
      expect(
          find.text('Los personajes sin una campaña activa no pueden subir de nivel.'),
          findsOneWidget);
      await app1.close(tester);
    },
        () => MockClient((req) async {
              if (req.url.path == '/api/v1/characters/p1') {
                return reply(hero(campaignId: null, experience: 500));
              }
              return normal(req);
            }));

    await http.runWithClient(() async {
      // Caso 2: Con campaña pero con XP insuficiente
      final app2 = _AppSession('u2');
      await app2.mount(tester, '/character/p1');
      await tester.tap(find.text('Subir Nivel'));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('El personaje requiere 300 XP para subir al nivel 2'),
          findsOneWidget);
      await app2.close(tester);
    },
        () => MockClient((req) async {
              if (req.url.path == '/api/v1/characters/p1') {
                return reply(hero(campaignId: 'c1', experience: 50));
              }
              return normal(req);
            }));
  });

  testWidgets(
      'Hoja de personaje en pantalla móvil (360x640) adapta layout sin desbordes',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await http.runWithClient(() async {
      final app = _AppSession('u2');
      await app.mount(tester, '/character/p1');
      await tester.pumpAndSettle();

      // Verificar que el header adaptado muestra el botón Subir Nivel sin recortar
      expect(find.text('Subir Nivel'), findsOneWidget);
      // Verificar que las tarjetas de combate y habilidades se renderizan
      expect(find.text('CA'), findsOneWidget);
      expect(find.text('PG Máx'), findsOneWidget);
      expect(find.text('Iniciativa'), findsOneWidget);
      expect(find.text('HABILIDADES', skipOffstage: false), findsOneWidget);

      await app.close(tester);
    }, () => MockClient(normal));
  });
}

