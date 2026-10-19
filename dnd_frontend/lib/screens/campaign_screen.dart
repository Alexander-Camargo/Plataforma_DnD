/// Archivo: campaign_screen.dart
/// Propósito: Pantalla principal de campaña para DM y Jugadores, con gestión de Control de Personajes, Hitos, Iniciativa y Notas.
/// Creador: Antigravity
/// Modificaciones / Actualizaciones:
/// - Renombrada pestaña 'Estado de Personajes' a 'Control de Personajes'.
/// - Añadido contador y badge de experiencia (XP) por personaje, junto con diálogo de otorgar XP para el DM.
/// - Añadida pestaña de 'Hitos' (Milestones) para definición, seguimiento y completado con otorgamiento automático de XP.

import 'package:flutter/material.dart';
import '../widgets/campaign_status_note_dialog.dart';
import '../widgets/quick_help.dart';
import '../core/data/tutorial_topics.dart';
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
  List<Milestone> _milestones = [];
  bool _isLoading = true;
  String? _error;

  // Rastreador de combate: solo vive durante esta sesión de pantalla.
  final Map<String, int> _currentHp = {};
  final Map<String, int> _initiative = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
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

      final List<dynamic> data =
          await _api.get('/characters/?campaign_id=${widget.campaignId}');
      final chars = data.map((e) => Character.fromJson(e)).toList();

      List<Milestone> milestones = [];
      try {
        final List<dynamic> mData =
            await _api.get('/campaigns/${widget.campaignId}/milestones');
        milestones = mData.map((e) => Milestone.fromJson(e)).toList();
      } catch (_) {
        // En caso de que no haya hitos o la ruta aún no devuelva datos
      }
      if (!mounted) return;

      final campaign = _findCampaign();
      setState(() {
        _characters = chars;
        _milestones = milestones;
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
        _characters = [
          for (final c in _characters) c.id == updated.id ? updated : c
        ];
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<String?> _askNote(String status) {
    return showDialog<String>(
      context: context,
      builder: (_) => CampaignStatusNoteDialog(
          statusLabel: DndRules.statuses[status] ?? status),
    );
  }

  Future<void> _saveNotes(Campaign campaign) async {
    final ok = await context
        .read<CampaignProvider>()
        .updateCampaignNotes(campaign.id, _notesCtrl.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              ok ? 'Notas guardadas.' : 'No se pudieron guardar las notas.')),
    );
  }

  Future<void> _awardXpDialog(Character char) async {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Otorgar XP a ${char.name}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('XP actual: ${char.experience} (Nivel ${char.level})'),
              const SizedBox(height: 12),
              TextFormField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cantidad de XP a sumar',
                  hintText: 'Ej: 150',
                  prefixIcon: Icon(Icons.star, color: AppColors.gold),
                ),
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n <= 0) return 'Ingresa un número mayor a 0';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Otorgar'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    final xpToAdd = int.parse(ctrl.text.trim());
    try {
      final res =
          await _api.post('/characters/${char.id}/award-xp', {'xp': xpToAdd});
      final updated = Character.fromJson(res);
      if (!mounted) return;
      setState(() {
        _characters = [
          for (final c in _characters) c.id == updated.id ? updated : c
        ];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Se otorgaron $xpToAdd XP a ${char.name}.')),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _createMilestoneDialog() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    int targetLevel = 2;
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nuevo Hito de Campaña'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Título del hito (ej: Rescatar el pueblo)',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingresa un título'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Descripción / Objetivo (opcional)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Nivel objetivo: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      DropdownButton<int>(
                        value: targetLevel,
                        items: List.generate(19, (i) => i + 2)
                            .map((lvl) => DropdownMenuItem(
                                value: lvl, child: Text('Nivel $lvl')))
                            .toList(),
                        onChanged: (lvl) {
                          if (lvl != null) {
                            setDialogState(() => targetLevel = lvl);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'XP al completar: ${DndRules.xpForLevel(targetLevel)} XP',
                    style: const TextStyle(
                        color: AppColors.gold, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Crear Hito'),
            ),
          ],
        ),
      ),
    );

    if (created != true || !mounted) return;
    try {
      await _api.post('/campaigns/${widget.campaignId}/milestones', {
        'title': titleCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'target_level': targetLevel,
        'xp_granted': DndRules.xpForLevel(targetLevel),
      });
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Hito creado con éxito.')));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _completeMilestone(Milestone m) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Completar Hito?'),
        content: Text(
          'Al completar "${m.title}", todos los aventureros recibirán ${m.xpGranted} XP para alcanzar el Nivel ${m.targetLevel}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar y Otorgar XP'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    try {
      await _api.patch('/campaigns/${widget.campaignId}/milestones/${m.id}', {
        'is_completed': true,
      });
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '¡Hito "${m.title}" completado! Se actualizó la XP de los personajes.')),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _deleteMilestone(Milestone m) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Hito?'),
        content: Text('¿Deseas eliminar el hito "${m.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    try {
      await _api.delete('/campaigns/${widget.campaignId}/milestones/${m.id}');
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Hito eliminado.')));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
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
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        (DndRules.statuses[c.status] ?? c.status).toUpperCase(),
        style:
            TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
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
              style: const TextStyle(
                  color: AppColors.gold, fontWeight: FontWeight.bold),
            ),
    );
  }

  String _subtitle(Character c) =>
      '${c.race} ${DndRules.displayClass(c.classSlug)} · Nivel ${c.level}'
      '${c.statusNote.isNotEmpty ? "\n“${c.statusNote}”" : ""}';

  Widget _xpBadge(Character c, {required bool isDM}) {
    final nextLevel = c.level + 1;
    final needed = DndRules.xpForLevel(nextLevel);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
            ),
            child: Text(
              '⭐ ${c.experience} / $needed XP (Nivel ${c.level})',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.gold,
              ),
            ),
          ),
          if (isDM)
            InkWell(
              onTap: () => _awardXpDialog(c),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 14, color: AppColors.gold),
                    Text(
                      'XP',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusList({required bool isDM}) {
    if (_characters.isEmpty) {
      return const EmptyState(
        icon: Icons.groups_outlined,
        message:
            'Ningún aventurero se ha unido aún.\nComparte el código de la campaña.',
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: _avatar(c),
              title: Text(c.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.accent)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_subtitle(c)),
                  _xpBadge(c, isDM: isDM),
                ],
              ),
              isThreeLine: true,
              trailing: isDM
                  ? PopupMenuButton<String>(
                      tooltip: 'Cambiar estado',
                      onSelected: (s) {
                        if (s == 'award_xp') {
                          _awardXpDialog(c);
                        } else {
                          _changeStatus(c, s);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'award_xp',
                          child: Row(
                            children: [
                              Icon(Icons.star, color: AppColors.gold, size: 18),
                              SizedBox(width: 8),
                              Text('Otorgar XP'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        ...DndRules.statuses.entries.map((e) => PopupMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            )),
                      ],
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _statusChip(c),
                          const Icon(Icons.arrow_drop_down)
                        ],
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
      return const EmptyState(
          icon: Icons.shield_moon_outlined,
          message: 'No hay personajes para el combate.');
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
                    style: TextStyle(
                        color: AppColors.muted, fontStyle: FontStyle.italic),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.sort),
                  label: const Text('Ordenar'),
                  onPressed: () => setState(() {
                    _characters.sort((a, b) => (_initiative[b.id] ?? 0)
                        .compareTo(_initiative[a.id] ?? 0));
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
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        ReorderableDragStartListener(
                          index: i,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child:
                                Icon(Icons.drag_handle, color: AppColors.muted),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accent)),
                              Text(
                                  '${c.race} ${DndRules.displayClass(c.classSlug)}',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.muted)),
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
                            onChanged: (v) =>
                                _initiative[c.id] = int.tryParse(v) ?? 0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.remove_circle,
                              color: AppColors.accent),
                          onPressed: hp > 0
                              ? () => setState(() => _currentHp[c.id] = hp - 1)
                              : null,
                        ),
                        SizedBox(
                          width: 56,
                          child: Text(
                            '$hp/$max',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  hp == 0 ? AppColors.accent : AppColors.text,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle,
                              color: AppColors.success),
                          onPressed: hp < max
                              ? () => setState(() => _currentHp[c.id] = hp + 1)
                              : null,
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
                  hintText:
                      'Tus notas secretas aquí. Los jugadores no pueden verlas.',
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

  Widget _milestonesTab({required bool isDM}) {
    if (_milestones.isEmpty) {
      return ContentWidth(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const EmptyState(
              icon: Icons.flag_outlined,
              message:
                  'No se han definido hitos para esta campaña.\nLos hitos permiten avanzar de nivel y otorgar XP.',
            ),
            if (isDM) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Crear Hito'),
                onPressed: _createMilestoneDialog,
              ),
            ],
          ],
        ),
      );
    }

    return ContentWidth(
      child: Column(
        children: [
          if (isDM)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Al completar un hito, todos los aventureros reciben la XP necesaria para subir de nivel.',
                      style: TextStyle(
                          color: AppColors.muted,
                          fontStyle: FontStyle.italic,
                          fontSize: 13),
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nuevo Hito'),
                    onPressed: _createMilestoneDialog,
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _milestones.length,
              itemBuilder: (context, i) {
                final m = _milestones[i];
                return Card(
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: m.isCompleted
                          ? AppColors.success.withValues(alpha: 0.2)
                          : AppColors.gold.withValues(alpha: 0.2),
                      child: Icon(
                        m.isCompleted ? Icons.check_circle : Icons.flag,
                        color:
                            m.isCompleted ? AppColors.success : AppColors.gold,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            m.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: m.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color:
                                    AppColors.accent.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'Nivel ${m.targetLevel} · ${m.xpGranted} XP',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (m.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(m.description),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          m.isCompleted
                              ? '✓ Hito completado'
                              : 'Pendiente por completar',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: m.isCompleted
                                ? AppColors.success
                                : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    trailing: isDM
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!m.isCompleted)
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text('Completar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                  ),
                                  onPressed: () => _completeMilestone(m),
                                )
                              else
                                const Icon(Icons.done_all,
                                    color: AppColors.success),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: AppColors.muted),
                                tooltip: 'Eliminar hito',
                                onPressed: () => _deleteMilestone(m),
                              ),
                            ],
                          )
                        : (m.isCompleted
                            ? const Icon(Icons.check_circle,
                                color: AppColors.success)
                            : null),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDmView(Campaign campaign) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.go('/')),
          title: Text(campaign.name),
          actions: [
            QuickHelp(topic: topicForLabel('Control de Personajes')!),
            QuickHelp(topic: topicForLabel('Hitos')!),
            QuickHelp(topic: topicForLabel('Iniciativa')!),
            QuickHelp(topic: topicForLabel('Notas Ocultas')!),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people), text: 'Control de Personajes'),
              Tab(icon: Icon(Icons.flag), text: 'Hitos'),
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
                children: [
                  _statusList(isDM: true),
                  _milestonesTab(isDM: true),
                  _combatTracker(),
                  _notesTab(campaign)
                ],
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
        actions: [
          QuickHelp(topic: topicForLabel('Control de Personajes')!),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          if (campaign.description.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppColors.bgCard,
              child: Text(campaign.description,
                  style: const TextStyle(color: AppColors.muted, height: 1.4)),
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
        appBar: AppBar(
            leading: BackButton(onPressed: () => context.go('/')),
            title: const Text('Campaña')),
        body: EmptyState(
            icon: Icons.error_outline,
            message: _error ?? 'No se encontró la campaña.'),
      );
    }

    return campaign.dmId == userId
        ? _buildDmView(campaign)
        : _buildPlayerView(campaign);
  }
}
