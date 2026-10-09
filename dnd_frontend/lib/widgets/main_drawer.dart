import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/campaign_provider.dart';
import '../providers/character_provider.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key});

  Widget _item(BuildContext context, IconData icon, String label, String route) {
    final current = GoRouterState.of(context).matchedLocation;
    final selected = current == route;
    return ListTile(
      leading: Icon(icon, color: selected ? AppColors.gold : Colors.white70),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? AppColors.gold : Colors.white,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: selected,
      selectedTileColor: Colors.white10,
      onTap: () {
        Navigator.pop(context); // Cierra el menú
        context.go(route);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.gold, width: 2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.gold,
                    child: Icon(Icons.person, size: 34, color: AppColors.bgDark),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.username ?? 'Aventurero',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Miembro del Gremio',
                    style: TextStyle(color: AppColors.gold, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _item(context, Icons.map, 'Campañas', '/'),
            _item(context, Icons.shield, 'Dungeon Master', '/dm-dashboard'),
            _item(context, Icons.people, 'Mis Personajes', '/my-characters'),
            _item(context, Icons.person_add, 'Crear Personaje', '/create-character'),
            const Spacer(),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white70),
              title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.white)),
              onTap: () {
                // Limpiamos los datos para no mostrar información del usuario anterior.
                context.read<CampaignProvider>().clear();
                context.read<CharacterProvider>().clear();
                context.read<AuthProvider>().logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}
