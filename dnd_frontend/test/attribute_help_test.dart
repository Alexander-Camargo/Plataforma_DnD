import 'fixtures/creation_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dnd_frontend/core/data/tutorial_topics.dart';
import 'package:dnd_frontend/core/router/app_router.dart';
import 'package:dnd_frontend/core/theme/app_theme.dart';
import 'package:dnd_frontend/providers/auth_provider.dart';
import 'package:dnd_frontend/screens/campaign_tutorial_screen.dart';

class _SignedInAuth extends AuthProvider {
  @override
  bool get isAuthenticated => true;
  @override
  bool get isLoading => false;
}

void main() {
  const attributes = [
    ('fue', 'Fuerza', 'strength'),
    ('des', 'Destreza', 'dexterity'),
    ('con', 'Constitución', 'constitution'),
    ('int', 'Inteligencia', 'intelligence'),
    ('sab', 'Sabiduría', 'wisdom'),
    ('car', 'Carisma', 'charisma'),
  ];
  for (final attribute in attributes) {
    testWidgets(
        'Ayuda de ${attribute.$2} está junto al nombre y abre su propio tema',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = _SignedInAuth();
      final router =
          AppRouter.createRouter(auth, creationCatalog: testCatalog())
            ..go('/create-character');
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child:
              MaterialApp.router(theme: AppTheme.light, routerConfig: router)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Lina');
      await tester.tap(find.text('Siguiente').hitTestable());
      await tester.pumpAndSettle();

      final topic = topicForLabel(attribute.$1)!;
      expect(topic.id, attribute.$3);
      expect(topicForLabel(attribute.$2)!.id, attribute.$3);
      final label =
          find.text('${attribute.$2} (${attribute.$1.toUpperCase()})');
      final help = find.byTooltip('Ayuda: ${topic.title}').first;
      await tester.ensureVisible(label);
      await tester.pumpAndSettle();
      final labelRect = tester.getRect(label);
      final helpRect = tester.getRect(help);
      expect(helpRect.left, greaterThanOrEqualTo(labelRect.right - 1));
      expect(helpRect.left - labelRect.right, lessThan(24));
      expect((helpRect.center.dy - labelRect.center.dy).abs(), lessThan(24));

      await tester.tap(help);
      await tester.pumpAndSettle();
      expect(find.text(topic.summary), findsOneWidget);
      expect(find.text('Saber más'), findsOneWidget);
      await tester.tap(find.text('Saber más'));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<CampaignTutorialScreen>(
                  find.byType(CampaignTutorialScreen))
              .section,
          attribute.$3);
      expect(find.text(topic.detail), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Puntos disponibles: 27 / 27'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      auth.dispose();
    });
  }

  testWidgets('Ayudas y controles de atributos no desbordan en móvil',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = _SignedInAuth();
    final router = AppRouter.createRouter(auth, creationCatalog: testCatalog())
      ..go('/create-character');
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child:
            MaterialApp.router(theme: AppTheme.light, routerConfig: router)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Lina');
    await tester.ensureVisible(find.text('Siguiente').first);
    await tester.tap(find.text('Siguiente').hitTestable());
    await tester.pumpAndSettle();
    for (final attribute in attributes) {
      final label =
          find.text('${attribute.$2} (${attribute.$1.toUpperCase()})');
      await tester.ensureVisible(label);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Ayuda: ${topicForLabel(attribute.$1)!.title}'),
          findsWidgets);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    auth.dispose();
  });
}
