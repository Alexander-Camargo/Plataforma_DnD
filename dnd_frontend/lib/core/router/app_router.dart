import '../../models/creation_catalog.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../screens/login_screen.dart';
import '../../screens/home_screen.dart';
import '../../screens/campaign_screen.dart';
import '../../screens/character_screen.dart';
import '../../screens/dm_dashboard_screen.dart';
import '../../screens/create_character_screen.dart';
import '../../screens/my_characters_screen.dart';
import '../../screens/campaign_tutorial_screen.dart';

class AppRouter {
  static GoRouter createRouter(AuthProvider authProvider,
      {CreationCatalog? creationCatalog}) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isAuthenticated = authProvider.isAuthenticated;
        final isLoginRoute = state.matchedLocation == '/login';

        if (!authProvider.isLoading) {
          if (!isAuthenticated && !isLoginRoute) return '/login';
          if (isAuthenticated && isLoginRoute) return '/';
        }
        return null;
      },
      routes: [
        GoRoute(
            path: '/login', builder: (context, state) => const LoginScreen()),
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(
            path: '/campaign-tutorial',
            builder: (context, state) => CampaignTutorialScreen(
                section: state.uri.queryParameters['section'])),
        GoRoute(
            path: '/my-characters',
            builder: (context, state) => const MyCharactersScreen()),
        GoRoute(
            path: '/dm-dashboard',
            builder: (context, state) => const DmDashboardScreen()),
        GoRoute(
            path: '/create-character',
            builder: (context, state) =>
                CreateCharacterScreen(catalog: creationCatalog)),
        GoRoute(
          path: '/campaign/:id',
          builder: (context, state) =>
              CampaignScreen(campaignId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/character/:id',
          builder: (context, state) =>
              CharacterScreen(characterId: state.pathParameters['id']!),
        ),
      ],
    );
  }
}
