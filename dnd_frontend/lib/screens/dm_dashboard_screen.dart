import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/campaign_provider.dart';
import '../widgets/main_drawer.dart';

class DmDashboardScreen extends StatefulWidget {
  const DmDashboardScreen({super.key});

  @override
  State<DmDashboardScreen> createState() => _DmDashboardScreenState();
}

class _DmDashboardScreenState extends State<DmDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Sin esto, entrar directo a esta pantalla (o recargar) mostraba la lista vacía.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CampaignProvider>().fetchMyCampaigns();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<CampaignProvider>();
    final userId = context.watch<AuthProvider>().currentUser?.id;
    final dmCampaigns = prov.campaigns.where((c) => c.dmId == userId).toList();

    return Scaffold(
      drawer: const MainDrawer(),
      appBar: AppBar(title: const Text('Dungeon Master')),
      body: prov.isLoading && prov.campaigns.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : dmCampaigns.isEmpty
              ? const EmptyState(
                  icon: Icons.shield_outlined,
                  message: 'No diriges ninguna campaña todavía.\nCrea una desde la pantalla de Campañas.',
                )
              : ContentWidth(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: dmCampaigns.length,
                    itemBuilder: (context, index) {
                      final c = dmCampaigns[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: ExpansionTile(
                          shape: const Border(),
                          collapsedShape: const Border(),
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.accent,
                            child: Icon(Icons.shield, color: AppColors.gold),
                          ),
                          title: Text(
                            c.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent),
                          ),
                          subtitle: Text('Código: ${c.joinCode}'),
                          children: [
                            ListTile(
                              leading: const Icon(Icons.copy),
                              title: const Text('Copiar código de invitación'),
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: c.joinCode));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Código copiado')),
                                );
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.people),
                              title: const Text('Entrar a la mesa de campaña'),
                              trailing: const Icon(Icons.chevron_right, color: AppColors.gold),
                              onTap: () => context.go('/campaign/${c.id}'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
