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
  testWidgets('El router real abre la guía desde ayuda y desde el menú',
      (tester) async {
    final auth = _SignedInAuth();
    final router = AppRouter.createRouter(auth);
    router.go('/create-character');
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Borrador conservado');
    await tester.tap(find.byTooltip('Ayuda: Raza'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saber más'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<CampaignTutorialScreen>(find.byType(CampaignTutorialScreen))
            .section,
        'race');
    expect(find.text(topicForLabel('Raza')!.detail), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Borrador conservado'), findsOneWidget);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guía de juego y de la app'));
    await tester.pumpAndSettle();
    expect(find.byType(CampaignTutorialScreen), findsOneWidget);
    expect(
        tester
            .widget<CampaignTutorialScreen>(find.byType(CampaignTutorialScreen))
            .section,
        isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    auth.dispose();
  });
}
