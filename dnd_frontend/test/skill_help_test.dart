import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dnd_frontend/core/data/tutorial_topics.dart';
import 'package:dnd_frontend/core/router/app_router.dart';
import 'package:dnd_frontend/core/theme/app_theme.dart';
import 'package:dnd_frontend/providers/auth_provider.dart';
import 'package:dnd_frontend/screens/campaign_tutorial_screen.dart';
import 'fixtures/creation_catalog.dart';

class SignedIn extends AuthProvider {
  @override
  bool get isAuthenticated => true;
  @override
  bool get isLoading => false;
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'Cada habilidad tiene ayuda propia y consultarla conserva las elecciones',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final catalog = testCatalog();
    final auth = SignedIn();
    final router = AppRouter.createRouter(auth, creationCatalog: catalog)
      ..go('/create-character');
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child:
            MaterialApp.router(theme: AppTheme.light, routerConfig: router)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bardo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('II. Atributos base'));
    await tester.pumpAndSettle();
    for (final skill in catalog.skills) {
      final row = find.widgetWithText(CheckboxListTile, skill['name']);
      expect(
          find.descendant(
              of: row, matching: find.byTooltip('Ayuda: ${skill['name']}')),
          findsOneWidget);
    }
    final arcana = find.widgetWithText(CheckboxListTile, 'Arcanos');
    final arcanaHelp =
        find.descendant(of: arcana, matching: find.byTooltip('Ayuda: Arcanos'));
    await reveal(tester, arcanaHelp);
    await tester.tap(arcanaHelp);
    await tester.pumpAndSettle();
    expect(find.text(topicForSkill('arcanos')!.summary), findsOneWidget);
    await tester.tap(find.text('Saber más'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<CampaignTutorialScreen>(find.byType(CampaignTutorialScreen))
            .section,
        'skill-arcanos');
    expect(find.text(topicForSkill('arcanos')!.detail), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(arcana).value, false);
    for (final name in ['Arcanos', 'Atletismo', 'Engaño']) {
      final row = find.widgetWithText(CheckboxListTile, name);
      await reveal(tester, row);
      await tester
          .tap(find.descendant(of: row, matching: find.byType(Checkbox)));
      await tester.pumpAndSettle();
    }
    final history = find.widgetWithText(CheckboxListTile, 'Historia');
    expect(tester.widget<CheckboxListTile>(history).onChanged, isNull);
    final historyHelp = find.descendant(
        of: history, matching: find.byTooltip('Ayuda: Historia'));
    await reveal(tester, historyHelp);
    await tester.tap(historyHelp);
    await tester.pumpAndSettle();
    expect(find.text(topicForSkill('historia')!.summary), findsOneWidget);
    await tester.tap(find.text('Saber más'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<CampaignTutorialScreen>(find.byType(CampaignTutorialScreen))
            .section,
        'skill-historia');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(arcana).value, true);
    expect(tester.widget<CheckboxListTile>(history).value, false);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    auth.dispose();
  });

  testWidgets(
      'Competencias raciales y del trasfondo tienen ayuda sin desbordar en móvil',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = SignedIn();
    final router = AppRouter.createRouter(auth, creationCatalog: testCatalog())
      ..go('/create-character');
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child:
            MaterialApp.router(theme: AppTheme.light, routerConfig: router)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Semiorco').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('II. Atributos base'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Competencias raciales'));
    expect(find.byTooltip('Ayuda: Intimidación'), findsWidgets);
    await tester.tap(
        find.byTooltip('Ayuda: Habilidades, salvaciones y competencia').first);
    await tester.pumpAndSettle();
    expect(find.text(topicForLabel('Competencias')!.summary), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    tester.widget<Stepper>(find.byType(Stepper)).onStepTapped!(2);
    await tester.pumpAndSettle();
    final background = find
        .ancestor(
            of: find.text('Competencias del trasfondo'),
            matching: find.byType(Column))
        .first;
    expect(
        find.descendant(
            of: background, matching: find.byTooltip('Ayuda: Perspicacia')),
        findsOneWidget);
    expect(
        find.descendant(
            of: background, matching: find.byTooltip('Ayuda: Religión')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    auth.dispose();
  });
}
