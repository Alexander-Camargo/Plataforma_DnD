import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:dnd_frontend/core/data/tutorial_topics.dart';
import 'package:dnd_frontend/core/theme/app_theme.dart';
import 'package:dnd_frontend/screens/campaign_tutorial_screen.dart';
import 'package:dnd_frontend/widgets/quick_help.dart';

void main() {
  testWidgets('Saber más abre el tema exacto y volver conserva el borrador',
      (tester) async {
    final controller = TextEditingController();
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
                  body: Column(children: [
                TextField(controller: controller),
                QuickHelp(topic: topicForLabel('Raza')!),
              ]))),
      GoRoute(
          path: '/campaign-tutorial',
          builder: (context, state) => CampaignTutorialScreen(
              section: state.uri.queryParameters['section'])),
    ]);
    await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router));
    await tester.enterText(find.byType(TextField), 'Mi aventurero');
    await tester.tap(find.byTooltip('Ayuda: Raza'));
    await tester.pumpAndSettle();
    expect(find.text(topicForLabel('Raza')!.summary), findsOneWidget);
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
    expect(find.text('Mi aventurero'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    controller.dispose();
  });
}
