import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/campaign_provider.dart';
import 'providers/character_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Iniciar la carga de autenticación sin bloquear el renderizado inicial de Flutter
  final authProvider = AuthProvider()..init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => CampaignProvider()),
        ChangeNotifierProvider(create: (_) => CharacterProvider()),
      ],
      child: const DndPlatformApp(),
    ),
  );
}

class DndPlatformApp extends StatefulWidget {
  const DndPlatformApp({super.key});

  @override
  State<DndPlatformApp> createState() => _DndPlatformAppState();
}

class _DndPlatformAppState extends State<DndPlatformApp> {
  // El router se crea UNA sola vez: crearlo en build() reiniciaba la
  // navegación a '/' cada vez que cambiaba el estado de autenticación.
  late final _router = AppRouter.createRouter(context.read<AuthProvider>());

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LA CRIPTA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
