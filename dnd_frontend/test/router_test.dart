import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dnd_frontend/core/router/app_router.dart';
import 'package:dnd_frontend/core/theme/app_theme.dart';
import 'package:dnd_frontend/providers/auth_provider.dart';
import 'package:dnd_frontend/screens/login_screen.dart';
import 'package:dnd_frontend/screens/campaign_tutorial_screen.dart';

class _LoggedOutAuth extends AuthProvider {
  @override
  bool get isAuthenticated => false;
  @override
  bool get isLoading => false;
}

void main() {
  for (final path in [
    '/create-character',
    '/campaign-tutorial?section=race',
    '/my-characters',
    '/dm-dashboard',
    '/campaign/unknown'
  ]) {
    testWidgets('Sin sesión $path redirige al login', (tester) async {
      final auth = _LoggedOutAuth();
      final router = AppRouter.createRouter(auth)..go(path);
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child:
              MaterialApp.router(theme: AppTheme.light, routerConfig: router)));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(CampaignTutorialScreen), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      auth.dispose();
    });
  }
}
