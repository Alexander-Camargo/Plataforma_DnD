import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/campaign_provider.dart';
import '../providers/character_provider.dart';
import '../models/models.dart';
import '../widgets/main_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CampaignProvider>().fetchMyCampaigns();
    });
  }

  Future<void> _openJoinDialog() async {
    final charProv = context.read<CharacterProvider>();
    await charProv.fetchMyCharacters();
    if (!mounted) return;

    final available = charProv.availableCharacters;
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No tienes personajes libres. Crea uno nuevo o termina la campaña de otro.'),
      ));
      return;
    }

    final joined = await showDialog<Campaign>(
      context: context,
      builder: (_) => _JoinCampaignDialog(characters: available),
    );
    if (joined != null && mounted) {
      await charProv.fetchMyCharacters();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Te has unido a "${joined.name}"')),
      );
    }
  }

  Future<void> _openCreateDialog() async {
    final created = await showDialog<Campaign>(
      context: context,
      builder: (_) => const _CreateCampaignDialog(),
    );
    if (created != null && mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¡Campaña creada!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Comparte este código con tus jugadores:'),
              const SizedBox(height: 12),
              Center(
                child: SelectableText(
                  created.joinCode,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copiar'),
              onPressed: () => Clipboard.setData(ClipboardData(text: created.joinCode)),
            ),
            ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Listo')),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaignProv = context.watch<CampaignProvider>();
    final userId = context.watch<AuthProvider>().currentUser?.id;

    return Scaffold(
      drawer: const MainDrawer(),
      appBar: AppBar(title: const Text('Campañas')),
      body: campaignProv.isLoading && campaignProv.campaigns.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : campaignProv.campaigns.isEmpty
              ? const EmptyState(
                  icon: Icons.map_outlined,
                  message: 'Aún no estás en ninguna campaña.\nÚnete con un código o crea la tuya.',
                )
              : RefreshIndicator(
                  onRefresh: campaignProv.fetchMyCampaigns,
                  child: ContentWidth(
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      itemCount: campaignProv.campaigns.length,
                      itemBuilder: (context, index) {
                        final c = campaignProv.campaigns[index];
                        final isDM = c.dmId == userId;
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: isDM ? AppColors.accent : AppColors.bgDark,
                              child: Icon(isDM ? Icons.shield : Icons.map, color: AppColors.gold),
                            ),
                            title: Text(
                              c.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent),
                            ),
                            subtitle: Text(
                              '${isDM ? "Dungeon Master" : "Jugador"} · '
                              '${c.description.isNotEmpty ? c.description : "Sin descripción"}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right, color: AppColors.gold),
                            onTap: () => context.go('/campaign/${c.id}'),
                          ),
                        );
                      },
                    ),
                  ),
                ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'btnJoin',
            onPressed: _openJoinDialog,
            icon: const Icon(Icons.group_add),
            label: const Text('Unirse'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'btnCreate',
            onPressed: _openCreateDialog,
            icon: const Icon(Icons.add),
            label: const Text('Crear campaña'),
          ),
        ],
      ),
    );
  }
}

class _JoinCampaignDialog extends StatefulWidget {
  final List<Character> characters;
  const _JoinCampaignDialog({required this.characters});

  @override
  State<_JoinCampaignDialog> createState() => _JoinCampaignDialogState();
}

class _JoinCampaignDialogState extends State<_JoinCampaignDialog> {
  final _codeCtrl = TextEditingController();
  late Character _selected = widget.characters.first;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Escribe el código de la campaña');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final prov = context.read<CampaignProvider>();
    final campaign = await prov.joinCampaign(code, _selected.id);
    if (!mounted) return;
    if (campaign != null) {
      Navigator.pop(context, campaign);
    } else {
      setState(() {
        _busy = false;
        _error = prov.lastError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Unirse a una campaña'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Código de unión'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Character>(
              value: _selected,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Personaje a usar'),
              items: widget.characters
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text('${c.name} (Nv. ${c.level})', overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selected = v ?? _selected),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFB3261E))),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: _busy ? null : _join, child: const Text('Unirse')),
      ],
    );
  }
}

class _CreateCampaignDialog extends StatefulWidget {
  const _CreateCampaignDialog();

  @override
  State<_CreateCampaignDialog> createState() => _CreateCampaignDialogState();
}

class _CreateCampaignDialogState extends State<_CreateCampaignDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'El nombre es obligatorio');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final prov = context.read<CampaignProvider>();
    final campaign = await prov.createCampaign(name, _descCtrl.text.trim());
    if (!mounted) return;
    if (campaign != null) {
      Navigator.pop(context, campaign);
    } else {
      setState(() {
        _busy = false;
        _error = prov.lastError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear campaña'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFB3261E))),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: _busy ? null : _create, child: const Text('Crear')),
      ],
    );
  }
}
