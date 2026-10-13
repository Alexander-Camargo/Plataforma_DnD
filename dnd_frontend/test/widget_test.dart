import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dnd_frontend/core/router/app_router.dart';
import 'package:dnd_frontend/core/theme/app_theme.dart';
import 'package:dnd_frontend/providers/auth_provider.dart';

class _SignedInAuth extends AuthProvider {
  @override
  bool get isAuthenticated => true;
  @override
  bool get isLoading => false;
}

void main() {
  testWidgets('Crear personaje exige nombre antes de avanzar', (tester) async {
    final auth = _SignedInAuth();
    final router = AppRouter.createRouter(auth)..go('/create-character');
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child:
            MaterialApp.router(theme: AppTheme.light, routerConfig: router)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Siguiente').hitTestable());
    await tester.pump();
    expect(find.text('Escribe el nombre del personaje.'), findsOneWidget);
    expect(find.byTooltip('Ayuda: Raza'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    auth.dispose();
  });
  testWidgets('El asistente conserva el nombre al avanzar y volver',
      (tester) async {
    final auth = _SignedInAuth();
    final router = AppRouter.createRouter(auth)..go('/create-character');
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child:
            MaterialApp.router(theme: AppTheme.light, routerConfig: router)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Lina');
    await tester.tap(find.text('Siguiente').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Puntos disponibles: 27 / 27'), findsOneWidget);
    await tester.ensureVisible(find.text('I. Identidad'));
    await tester.tap(find.text('I. Identidad'));
    await tester.pumpAndSettle();
    expect(find.text('Lina'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    auth.dispose();
  });
}
