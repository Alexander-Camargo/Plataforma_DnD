import 'package:dnd_frontend/core/data/tutorial_topics.dart';
import 'package:dnd_frontend/screens/campaign_tutorial_screen.dart';
import 'package:dnd_frontend/providers/campaign_provider.dart';
import 'package:dnd_frontend/providers/character_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:dnd_frontend/core/router/app_router.dart';
import 'package:dnd_frontend/core/theme/app_theme.dart';
import 'package:dnd_frontend/providers/auth_provider.dart';
import 'fixtures/creation_catalog.dart';

class SignedIn extends AuthProvider {
  @override
  bool get isAuthenticated => true;
  @override
  bool get isLoading => false;
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
      'Elfo permite seleccionar subraza y semielfo elegir sus bonificadores',
      (tester) async {
    final auth = SignedIn();
    final router = AppRouter.createRouter(auth, creationCatalog: testCatalog())
      ..go('/create-character');
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => CharacterProvider()),
              ChangeNotifierProvider(create: (_) => CampaignProvider())
            ],
            child: MaterialApp.router(
                theme: AppTheme.light, routerConfig: router))));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elfo').last);
    await tester.pumpAndSettle();
    expect(find.text('Subraza'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(4));
    final raceRect =
        tester.getRect(find.byType(DropdownButtonFormField<String>).at(0));
    final subraceRect =
        tester.getRect(find.byType(DropdownButtonFormField<String>).at(1));
    expect(subraceRect.left, closeTo(raceRect.left, 0.01));
    expect(subraceRect.right, closeTo(raceRect.right, 0.01));
    await tester.tap(find.byTooltip('Ayuda: Subraza'));
    await tester.pumpAndSettle();
    expect(find.text(topicForLabel('Subraza')!.summary), findsOneWidget);
    await tester.tap(find.text('Saber más'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<CampaignTutorialScreen>(find.byType(CampaignTutorialScreen))
            .section,
        'subrace');
    expect(find.text(topicForLabel('Subraza')!.detail), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Subraza'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Semielfo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('II. Atributos base'));
    await tester.pumpAndSettle();
    final bonus = find.text(
        'Bonificadores raciales: +1 a dos características distintas (0/2)');
    await reveal(tester, bonus);
    expect(bonus, findsOneWidget);
    final strength = find.widgetWithText(CheckboxListTile, 'Fuerza');
    await reveal(tester, strength);
    await tester.tap(strength);
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Bonificadores raciales: +1 a dos características distintas (1/2)'),
        findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Carisma'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    auth.dispose();
  });

  testWidgets('Guardar requiere competencias y envía elecciones al servidor',
      (tester) async {
    Map<String, dynamic>? sent;
    await http.runWithClient(() async {
      final auth = SignedIn();
      final router =
          AppRouter.createRouter(auth, creationCatalog: testCatalog())
            ..go('/create-character');
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => CharacterProvider()),
                ChangeNotifierProvider(create: (_) => CampaignProvider())
              ],
              child: MaterialApp.router(
                  theme: AppTheme.light, routerConfig: router))));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Lina');
      await reveal(tester, find.text('IV. Resumen final'));
      await tester.tap(find.text('IV. Resumen final'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Guardar personaje').last);
      await tester.tap(find.text('Guardar personaje').last);
      await tester.pumpAndSettle();
      expect(sent, isNull);
      expect(find.text('Elige todas las competencias de tu clase.'),
          findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      for (final name in ['Atletismo', 'Historia']) {
        final tile = find.widgetWithText(CheckboxListTile, name);
        await reveal(tester, tile);
        await tester.tap(tile);
        await tester.pumpAndSettle();
      }
      await reveal(tester, find.text('IV. Resumen final'));
      await tester.tap(find.text('IV. Resumen final'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Guardar personaje').last);
      await tester.tap(find.text('Guardar personaje').last);
      await tester.pumpAndSettle();
      expect(sent!['creation']['class_skills'], ['atletismo', 'historia']);
      expect(sent!['creation']['base_stats']['fue'], 8);
      expect(sent!['sheet'].containsKey('stats'), false);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      auth.dispose();
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                sent = jsonDecode(request.body);
                return http.Response('{}', 201);
              }
              return http.Response('[]', 200);
            }));
  });
}
