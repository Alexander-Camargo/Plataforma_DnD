import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../core/data/dnd_rules.dart';
import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../providers/campaign_provider.dart';
import '../providers/character_provider.dart';
import '../widgets/main_drawer.dart';

class MyCharactersScreen extends StatefulWidget {
  const MyCharactersScreen({super.key});

  @override
  State<MyCharactersScreen> createState() => _MyCharactersScreenState();
}

class _MyCharactersScreenState extends State<MyCharactersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CharacterProvider>().fetchMyCharacters();
      context.read<CampaignProvider>().fetchMyCampaigns();
    });
  }

  Future<void> _leaveCampaign(Character char, String campaignName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminar campaña'),
        content: Text(
          '${char.name} dejará "$campaignName" y la campaña quedará en su historial. '
          'Después podrás unirlo a otra.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Terminar')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final prov = context.read<CharacterProvider>();
    final ok = await prov.leaveCampaign(char);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Campaña terminada.' : (prov.lastError ?? 'Error al actualizar.'))),
    );
    if (!ok) prov.fetchMyCharacters(); // Posible desincronización de versión
  }

  Widget _summaryChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgStat,
        border: Border.all(color: AppColors.borderStat),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 16, color: AppColors.accent, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: AppColors.accent,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _characterCard(Character char, Map<String, String> campaignNames) {
    final stats = (char.sheet['stats'] as Map?) ?? {};
    final mods = (char.sheet['modifiers'] as Map?) ?? {};
    final history = char.campaignHistory;
    final campaignName = campaignNames[char.campaignId] ?? 'Campaña activa';
    final hasImg = char.avatarUrl != null && char.avatarUrl!.isNotEmpty;

    String mod(String k) {
      final m = (mods[k] as num?)?.toInt() ?? 0;
      return m >= 0 ? '+$m' : '$m';
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.bgDark,
          backgroundImage: hasImg ? NetworkImage(char.avatarUrl!) : null,
          child: hasImg
              ? null
              : Text(
                  char.name.isEmpty ? '?' : char.name[0].toUpperCase(),
                  style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 20),
                ),
        ),
        title: Text(
          char.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.accent),
        ),
        subtitle: Text(
          '${char.race} ${DndRules.displayClass(char.classSlug)} · Nivel ${char.level}\n'
          '${char.inCampaign ? "⚔️ En campaña: $campaignName" : "🏕️ Descansando"}',
        ),
        children: [
          // Resumen (igual que el resumen final de la creación)
          _sectionTitle('Resumen'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip('PG', '${char.sheet['hp'] ?? '-'}'),
              _summaryChip('CA', '${char.sheet['ac'] ?? '-'}'),
              _summaryChip('VEL', '${char.sheet['speed'] ?? 30} ft'),
              for (final k in DndRules.statNames.keys)
                _summaryChip(k.toUpperCase(), '${stats[k] ?? 10} (${mod(k)})'),
            ],
          ),

          _sectionTitle('Campaña actual'),
          if (char.inCampaign) ...[
            Text('⚔️ $campaignName'),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _leaveCampaign(char, campaignName),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Terminar campaña'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.accent),
              ),
            ),
          ] else
            const Text('Sin campaña activa. Puede unirse a una nueva.',
                style: TextStyle(color: AppColors.muted, fontStyle: FontStyle.italic)),

          _sectionTitle('Historial de campañas'),
          if (history.isEmpty)
            const Text('Aún no ha terminado ninguna campaña.',
                style: TextStyle(color: AppColors.muted, fontStyle: FontStyle.italic))
          else
            for (final h in history.reversed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '• ${h['name'] ?? 'Campaña'}'
                  '${h['final_status'] != null ? " (${DndRules.statuses[h['final_status']] ?? h['final_status']})" : ""}',
                ),
              ),

          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => context.go('/character/${char.id}'),
            icon: const Icon(Icons.edit_document),
            label: const Text('Abrir hoja de personaje'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final charProv = context.watch<CharacterProvider>();
    final campaigns = context.watch<CampaignProvider>().campaigns;
    final campaignNames = {for (final c in campaigns) c.id: c.name};

    return Scaffold(
      drawer: const MainDrawer(),
      appBar: AppBar(title: const Text('Mis Personajes')),
      body: charProv.isLoading && charProv.myCharacters.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : charProv.myCharacters.isEmpty
              ? const EmptyState(
                  icon: Icons.person_add_alt_1_outlined,
                  message: 'Aún no has forjado ningún aventurero.\nUsa “Crear Personaje” en el menú.',
                )
              : RefreshIndicator(
                  onRefresh: charProv.fetchMyCharacters,
                  child: ContentWidth(
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: charProv.myCharacters.length,
                      itemBuilder: (context, index) =>
                          _characterCard(charProv.myCharacters[index], campaignNames),
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/create-character'),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo personaje'),
      ),
    );
  }
}
