import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/api/api_client.dart';
import '../core/data/dnd_rules.dart';
import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/campaign_provider.dart';

class CampaignScreen extends StatefulWidget {
  final String campaignId;
  const CampaignScreen({super.key, required this.campaignId});

  @override
  State<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends State<CampaignScreen> {
  final ApiClient _api = ApiClient();
  final TextEditingController _notesCtrl = TextEditingController();

  List<Character> _characters = [];
  bool _isLoading = true;
  String? _error;

  // Rastreador de combate: solo vive durante esta sesión de pantalla.
  final Map<String, int> _currentHp = {};
  final Map<String, int> _initiative = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Campaign? _findCampaign() {
    final list = context.read<CampaignProvider>().campaigns;
    final i = list.indexWhere((c) => c.id == widget.campaignId);
    return i == -1 ? null : list[i];
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final campaignProv = context.read<CampaignProvider>();
      // Si se entró directo por URL/recarga, la lista de campañas puede estar vacía.
      if (_findCampaign() == null) await campaignProv.fetchMyCampaigns();

      final List<dynamic> data = await _api.get('/characters/?campaign_id=${widget.campaignId}');
      final chars = data.map((e) => Character.fromJson(e)).toList();
      if (!mounted) return;

      final campaign = _findCampaign();
      setState(() {
        _characters = chars;
        for (final c in chars) {
          _currentHp.putIfAbsent(c.id, () => _maxHp(c));
          _initiative.putIfAbsent(c.id, () => 0);
        }
        _notesCtrl.text = campaign?.dmNotes ?? '';
        _error = campaign == null ? 'No se encontró la campaña.' : null;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    }
  }

  int _maxHp(Character c) => (c.sheet['hp'] as num?)?.toInt() ?? 10;

  Future<void> _changeStatus(Character char, String newStatus) async {
    if (newStatus == char.status) return;
    final note = await _askNote(newStatus);
    if (note == null || !mounted) return; // cancelado

    try {
      final data = await _api.patch('/characters/${char.id}/status', {
        'status': newStatus,
        'status_note': note,
      });
      final updated = Character.fromJson(data);
      if (!mounted) return;
      setState(() {
        _characters = [for (final c in _characters) c.id == updated.id ? updated : c];
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<String?> _askNote(String status) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Marcar como: ${DndRules.statuses[status] ?? status}'),
        content: TextField(
          controller: ctrl,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'Nota (opcional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Confirmar')),
        ],
      ),
    ).whenComplete(ctrl.dispose);
  }

  Future<void> _saveNotes(Campaign campaign) async {
    final ok = await context.read<CampaignProvider>().updateCampaignNotes(campaign.id, _notesCtrl.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Notas guardadas.' : 'No se pudieron guardar las notas.')),
    );
  }

  // ---------- Widgets compartidos ----------
  Color _statusColor(String status) {
    switch (status) {
      case 'alive':
      case 'resurrected':
        return AppColors.success;
      case 'dead':
        return AppColors.accent;
      case 'undead':
        return const Color(0xFF4A148C);
      default:
        return AppColors.muted;
    }
  }

  Widget _statusChip(Character c) {
    final color = _statusColor(c.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        (DndRules.statuses[c.status] ?? c.status).toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _avatar(Character c) {
    final hasImg = c.avatarUrl != null && c.avatarUrl!.isNotEmpty;
    return CircleAvatar(
      backgroundColor: AppColors.bgDark,
      backgroundImage: hasImg ? NetworkImage(c.avatarUrl!) : null,
      child: hasImg
          ? null
          : Text(
              c.name.isEmpty ? '?' : c.name[0].toUpperCase(),
              style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
            ),
    );
  }

  String _subtitle(Character c) =>
      '${c.race} ${DndRules.displayClass(c.classSlug)} · Nivel ${c.level}'
      '${c.statusNote.isNotEmpty ? "\n“${c.statusNote}”" : ""}';

  Widget _statusList({required bool isDM}) {
    if (_characters.isEmpty) {
      return const EmptyState(
        icon: Icons.groups_outlined,
        message: 'Ningún aventurero se ha unido aún.\nComparte el código de la campaña.',
      );
    }
    return ContentWidth(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _characters.length,
        itemBuilder: (context, index) {
          final c = _characters[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: _avatar(c),
              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent)),
              subtitle: Text(_subtitle(c)),
              isThreeLine: c.statusNote.isNotEmpty,
              trailing: isDM
                  ? PopupMenuButton<String>(
                      tooltip: 'Cambiar estado',
                      onSelected: (s) => _changeStatus(c, s),
                      itemBuilder: (_) => DndRules.statuses.entries
                          .map((e) => PopupMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ))
                          .toList(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [_statusChip(c), const Icon(Icons.arrow_drop_down)],
                      ),
                    )
                  : _statusChip(c),
              onTap: () => context.go('/character/${c.id}'),
            ),
          );
        },
      ),
    );
  }

  // ---------- Vista del DM ----------
  Widget _combatTracker() {
    if (_characters.isEmpty) {
      return const EmptyState(icon: Icons.shield_moon_outlined, message: 'No hay personajes para el combate.');
    }
    return ContentWidth(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Anota la iniciativa de cada uno y ordena. Los PG son solo de esta sesión.',
                    style: TextStyle(color: AppColors.muted, fontStyle: FontStyle.italic),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.sort),
                  label: const Text('Ordenar'),
                  onPressed: () => setState(() {
                    _characters.sort((a, b) => (_initiative[b.id] ?? 0).compareTo(_initiative[a.id] ?? 0));
                  }),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reiniciar'),
                  onPressed: () => setState(() {
                    for (final c in _characters) {
                      _currentHp[c.id] = _maxHp(c);
                      _initiative[c.id] = 0;
                    }
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              buildDefaultDragHandles: false,
              itemCount: _characters.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (oldIndex < newIndex) newIndex -= 1;
                  _characters.insert(newIndex, _characters.removeAt(oldIndex));
                });
              },
              itemBuilder: (context, i) {
                final c = _characters[i];
                final hp = _currentHp[c.id] ?? _maxHp(c);
                final max = _maxHp(c);
                return Card(
                  key: ValueKey(c.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        ReorderableDragStartListener(
                          index: i,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.drag_handle, color: AppColors.muted),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent)),
                              Text('${c.race} ${DndRules.displayClass(c.classSlug)}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 64,
                          child: TextFormField(
                            key: ValueKey('ini-${c.id}-${_initiative[c.id]}'),
                            initialValue: '${_initiative[c.id] ?? 0}',
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              labelText: 'Inic.',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                            onChanged: (v) => _initiative[c.id] = int.tryParse(v) ?? 0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: AppColors.accent),
                          onPressed: hp > 0 ? () => setState(() => _currentHp[c.id] = hp - 1) : null,
                        ),
                        SizedBox(
                          width: 56,
                          child: Text(
                            '$hp/$max',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: hp == 0 ? AppColors.accent : AppColors.text,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: AppColors.success),
                          onPressed: hp < max ? () => setState(() => _currentHp[c.id] = hp + 1) : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _notesTab(Campaign campaign) {
    return ContentWidth(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _notesCtrl,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Tus notas secretas aquí. Los jugadores no pueden verlas.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Guardar notas'),
              onPressed: () => _saveNotes(campaign),
            ),
          ],
        ),
      ),
    );
  }

  Widget _joinCodeBanner(Campaign campaign) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.bgDark,
      child: Text(
        'Código de invitación: ${campaign.joinCode}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.gold, letterSpacing: 1),
      ),
    );
  }

  Widget _buildDmView(Campaign campaign) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.go('/')),
          title: Text(campaign.name),
          actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.favorite), text: 'Estado de Personajes'),
              Tab(icon: Icon(Icons.shield_moon), text: 'Iniciativa y Combate'),
              Tab(icon: Icon(Icons.menu_book), text: 'Notas Ocultas'),
            ],
          ),
        ),
        body: Column(
          children: [
            _joinCodeBanner(campaign),
            Expanded(
              child: TabBarView(
                children: [_statusList(isDM: true), _combatTracker(), _notesTab(campaign)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerView(Campaign campaign) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: Text(campaign.name),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: Column(
        children: [
          if (campaign.description.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppColors.bgCard,
              child: Text(campaign.description, style: const TextStyle(color: AppColors.muted, height: 1.4)),
            ),
          Expanded(child: _statusList(isDM: false)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Escuchamos al provider para reaccionar a cambios (p. ej. notas guardadas).
    context.watch<CampaignProvider>();
    final userId = context.watch<AuthProvider>().currentUser?.id;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final campaign = _findCampaign();
    if (_error != null || campaign == null) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.go('/')), title: const Text('Campaña')),
        body: EmptyState(icon: Icons.error_outline, message: _error ?? 'No se encontró la campaña.'),
      );
    }

    return campaign.dmId == userId ? _buildDmView(campaign) : _buildPlayerView(campaign);
  }
}
