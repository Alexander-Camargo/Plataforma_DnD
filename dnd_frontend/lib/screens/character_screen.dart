/*
Archivo: character_screen.dart
Propósito: Pantalla de hoja de personaje de D&D 5e con pestañas de estadísticas, trasfondo, rasgos dinámicos, equipo, acciones, conjuros y subida de nivel.
Creador: Alexander Camargo / Joshua Pérez Bullen
Modificaciones / Actualizaciones:
- 2026-10-08 [Alexander Camargo]: Creación de la pantalla de hoja de personaje con pestañas y exportación PDF.
- 2026-10-12 [Joshua Pérez Bullen]: Ayuda contextual rápida y bonificadores de competencia/pericia.
- 2026-10-18 [Alexander Camargo]: Integración del diálogo guiado de subida de nivel 5e (Hito 3.1) y renderizado dinámico de rasgos y subclase.
- 2026-10-18 [Alexander Camargo]: Restricción de subida de nivel para personajes con campaña activa y experiencia requerida, visualización de badge de XP.
- 2026-10-19 [Alexander Camargo]: Diseño responsive para móviles (LayoutBuilder, apilado dinámico de estadísticas y combate, botón de subir nivel adaptable).
*/

import '../core/data/dnd_rules.dart';
import 'package:flutter/material.dart';
import '../widgets/quick_help.dart';
import '../widgets/level_up_dialog.dart';
import '../core/data/tutorial_topics.dart';
import 'package:go_router/go_router.dart';
import '../core/api/api_client.dart';
import '../models/models.dart';
import '../core/theme/app_theme.dart';
import '../utils/pdf_generator.dart';
import '../widgets/network_avatar.dart';

class CharacterScreen extends StatefulWidget {
  final String characterId;
  const CharacterScreen({super.key, required this.characterId});

  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  final ApiClient _api = ApiClient();
  Character? _character;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  // Controladores para la edición
  final TextEditingController _caCtrl = TextEditingController();
  final TextEditingController _hpCtrl = TextEditingController();
  final TextEditingController _speedCtrl = TextEditingController();
  final TextEditingController _avatarCtrl = TextEditingController();

  final TextEditingController _historyCtrl = TextEditingController();
  final TextEditingController _physicalCtrl = TextEditingController();
  final TextEditingController _idealsCtrl = TextEditingController();
  final TextEditingController _bondsCtrl = TextEditingController();
  final TextEditingController _flawsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCharacter();
  }

  Future<void> _fetchCharacter() async {
    try {
      final data = await _api.get('/characters/${widget.characterId}');
      if (mounted) {
        setState(() {
          _character = Character.fromJson(data);
          _initControllers();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching character: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initControllers() {
    if (_character == null) return;
    final c = _character!;
    final bg = c.sheet['background'] as Map<String, dynamic>? ?? {};

    _caCtrl.text = '${c.sheet['ac'] ?? 10}';
    _hpCtrl.text = '${c.sheet['hp'] ?? 10}';
    _speedCtrl.text = '${c.sheet['speed'] ?? 30}';
    _avatarCtrl.text = c.avatarUrl ?? '';

    _historyCtrl.text = bg['history'] ?? '';
    _physicalCtrl.text = bg['physical'] ?? '';
    _idealsCtrl.text = bg['ideals'] ?? '';
    _bondsCtrl.text = bg['bonds'] ?? '';
    _flawsCtrl.text = bg['flaws'] ?? '';
  }

  Future<void> _saveChanges() async {
    if (_character == null) return;
    setState(() => _isSaving = true);

    try {
      final newSheet = Map<String, dynamic>.from(_character!.sheet);

      newSheet['ac'] = int.tryParse(_caCtrl.text) ?? 10;
      newSheet['hp'] = int.tryParse(_hpCtrl.text) ?? 10;
      newSheet['speed'] = int.tryParse(_speedCtrl.text) ?? 30;

      final bg = Map<String, dynamic>.from(newSheet['background'] ?? {});
      bg['history'] = _historyCtrl.text;
      bg['physical'] = _physicalCtrl.text;
      bg['ideals'] = _idealsCtrl.text;
      bg['bonds'] = _bondsCtrl.text;
      bg['flaws'] = _flawsCtrl.text;
      newSheet['background'] = bg;

      final data = await _api.patch('/characters/${_character!.id}', {
        'sheet': newSheet,
        'avatar_url': _avatarCtrl.text.trim(),
        'version': _character!.version,
      });

      if (mounted) {
        setState(() {
          _character = Character.fromJson(data);
          _isEditing = false;
          _isSaving = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cambios guardados con éxito.')));
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    }
  }

  Future<void> _levelUp() async {
    if (_character == null) return;
    if (_character!.level >= 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('El personaje ya alcanzó el nivel máximo (20).')),
      );
      return;
    }
    if (!_character!.inCampaign) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Los personajes sin una campaña activa no pueden subir de nivel.'),
        ),
      );
      return;
    }
    final nextLevel = _character!.level + 1;
    final requiredXp = DndRules.xpForLevel(nextLevel);
    if (_character!.experience < requiredXp) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'El personaje requiere $requiredXp XP para subir al nivel $nextLevel '
            '(experiencia actual: ${_character!.experience} XP). Tu DM debe completar un hito u otorgar experiencia.',
          ),
        ),
      );
      return;
    }

    final choices = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => LevelUpDialog(character: _character!),
    );
    if (choices == null || !mounted) return;

    final newLevel = _character!.level + 1;
    try {
      final data = await _api.patch('/characters/${_character!.id}', {
        'version': _character!.version,
        'level': newLevel,
        'level_up': choices,
      });
      if (!mounted) return;
      setState(() {
        _character = Character.fromJson(data);
        _initControllers();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('¡Felicidades! Has alcanzado el nivel $newLevel.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir de nivel: $e')),
      );
    }
  }

  // UI Builders
  Widget _buildStatBox(String label, int score, int mod,
      {bool isNarrow = false}) {
    final modStr = mod >= 0 ? '+$mod' : '$mod';
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isNarrow ? 2 : 4),
      padding: EdgeInsets.symmetric(
          vertical: isNarrow ? 6 : 8, horizontal: isNarrow ? 2 : 4),
      decoration: BoxDecoration(
        color: AppColors.bgStat,
        border: Border.all(color: AppColors.borderStat, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                  fontSize: isNarrow ? 11 : 13)),
          QuickHelp(topic: topicForLabel(label)!),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Text(modStr,
                style: TextStyle(
                    fontSize: isNarrow ? 18 : 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent)),
          ),
          Container(
            padding: const EdgeInsets.only(top: 2),
            decoration: const BoxDecoration(
                border:
                    Border(top: BorderSide(color: AppColors.gold, width: 1))),
            child: Text('$score',
                style: TextStyle(
                    fontSize: isNarrow ? 11 : 13, color: AppColors.muted)),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallCard(String title, String value,
      {TextEditingController? ctrl}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 4),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Text(title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
          if (topicForLabel(title) != null)
            QuickHelp(topic: topicForLabel(title)!),
          const SizedBox(height: 6),
          if (_isEditing && ctrl != null)
            TextField(
              controller: ctrl,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent),
              decoration: const InputDecoration(
                  isDense: true, contentPadding: EdgeInsets.all(4)),
            )
          else
            Text(value,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent)),
        ],
      ),
    );
  }

  Widget _buildListCard(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 6),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Text(title.toUpperCase(),
                style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5)),
          ),
          if (topicForLabel(title) != null)
            Align(
              alignment: Alignment.centerRight,
              child: QuickHelp(topic: topicForLabel(title)!),
            ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildListItem(String label, String value,
      {bool isProficient = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Text(isProficient ? '● ' : '○ ',
            style: TextStyle(
                color: isProficient ? AppColors.accent : Colors.grey,
                fontSize: 12)),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        const SizedBox(width: 8),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.accent)),
      ]),
    );
  }

  Widget _buildEditableText(String text, TextEditingController ctrl,
      {int maxLines = 1}) {
    if (_isEditing) {
      return TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14),
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.all(12),
        ),
      );
    }
    return Text(text.isEmpty ? 'No definido.' : text,
        style:
            const TextStyle(fontSize: 14, color: AppColors.text, height: 1.5));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_character == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Error')),
          body: const Center(child: Text('Error al cargar.')));
    }

    final c = _character!;
    final stats = c.sheet['stats'] as Map<String, dynamic>? ?? {};
    final mods = c.sheet['modifiers'] as Map<String, dynamic>? ?? {};
    final bg = c.sheet['background'] as Map<String, dynamic>? ?? {};
    final saves = c.sheet['saves'] as Map<String, dynamic>? ?? {};
    final eq = c.sheet['equipment'] as List<dynamic>? ?? [];

    return DefaultTabController(
      length: 7,
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        appBar: AppBar(
          backgroundColor: AppColors.bgDark, // Más limpio, todo oscuro
          foregroundColor: AppColors.gold,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Volver',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/my-characters');
              }
            },
          ),
          title: Text(c.name,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, letterSpacing: 1)),
          elevation: 0,
          actions: [
            if (_isEditing) ...[
              TextButton.icon(
                onPressed: () => setState(() {
                  _isEditing = false;
                  _initControllers();
                }), // Cancelar
                icon: const Icon(Icons.close, color: Colors.grey),
                label: const Text('Cancelar',
                    style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveChanges,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save, size: 18),
                label: const Text('Guardar'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white),
              ),
            ] else ...[
              IconButton(
                onPressed: () =>
                    PdfGenerator.generateCharacterSheet(context, _character!),
                icon: const Icon(Icons.picture_as_pdf),
                tooltip: 'Descargar PDF',
              ),
              ElevatedButton.icon(
                onPressed: () => setState(() => _isEditing = true),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Editar'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white),
              ),
            ],
            const SizedBox(width: 16),
          ],
          bottom: const TabBar(
            isScrollable: true,
            labelColor: AppColors.gold,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.gold,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: 'Visión General'),
              Tab(text: 'Información General'),
              Tab(text: 'Trasfondo'),
              Tab(text: 'Rasgos'),
              Tab(text: 'Equipo'),
              Tab(text: 'Acciones'),
              Tab(text: 'Conjuros'),
            ],
          ),
        ),
        body: Container(
          color: AppColors.bgCard,
          child: Column(
            children: [
              // HEADER HOJA MÁS LIMPIO Y PROFESIONAL
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 620;
                  final avatarWidget = CircleAvatar(
                    radius: isNarrow ? 24 : 28,
                    backgroundColor: AppColors.gold,
                    backgroundImage:
                        c.avatarUrl != null && c.avatarUrl!.isNotEmpty
                            ? NetworkImage(c.avatarUrl!)
                            : null,
                    child: (c.avatarUrl == null || c.avatarUrl!.isEmpty)
                        ? Icon(Icons.person,
                            size: isNarrow ? 26 : 30, color: AppColors.bgDark)
                        : null,
                  );

                  final titleAndBadges = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${c.race} ${c.classSlug.toUpperCase()} - Nivel ${c.level}',
                        style: TextStyle(
                            fontSize: isNarrow ? 14 : 16,
                            color: AppColors.border,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: c.campaignId != null
                                  ? AppColors.accent
                                  : AppColors.muted,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.gold, width: 1),
                            ),
                            child: Text(
                              c.campaignId != null
                                  ? '⚔️ En Campaña'
                                  : '🏕️ Descansando',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: isNarrow ? 11 : 12,
                                  color: Colors.white),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.bgStat,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.gold, width: 1),
                            ),
                            child: Text(
                              c.level >= 20
                                  ? '⭐ ${c.experience} XP'
                                  : '⭐ ${c.experience} / ${DndRules.xpForLevel(c.level + 1)} XP',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: isNarrow ? 11 : 12,
                                  color: AppColors.gold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );

                  final levelUpBtn = ElevatedButton.icon(
                    onPressed: _levelUp,
                    icon: const Icon(Icons.arrow_upward, size: 16),
                    label: const Text('Subir Nivel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bgDark,
                      padding: EdgeInsets.symmetric(
                          horizontal: isNarrow ? 12 : 16,
                          vertical: isNarrow ? 8 : 10),
                    ),
                  );

                  return Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: isNarrow ? 14 : 24,
                        vertical: isNarrow ? 12 : 16),
                    decoration: const BoxDecoration(
                      color: AppColors.bgDark,
                      border: Border(
                          bottom: BorderSide(color: AppColors.gold, width: 2)),
                    ),
                    child: ContentWidth(
                      maxWidth: 1000,
                      child: isNarrow
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    avatarWidget,
                                    const SizedBox(width: 12),
                                    Expanded(child: titleAndBadges),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                levelUpBtn,
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      avatarWidget,
                                      const SizedBox(width: 16),
                                      Expanded(child: titleAndBadges),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                levelUpBtn,
                              ],
                            ),
                    ),
                  );
                },
              ),

              // TAB CONTENT
              Expanded(
                child: TabBarView(
                  children: [
                    // TAB 1: Visión General
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 720;
                        final combatCards = Row(
                          children: [
                            Expanded(
                                child: _buildSmallCard(
                                    'CA', '${c.sheet['ac'] ?? 10}',
                                    ctrl: _caCtrl)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: _buildSmallCard('PG Máx',
                                    '${c.sheet['hp'] ?? 10}',
                                    ctrl: _hpCtrl)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: _buildSmallCard(
                                    'Iniciativa',
                                    (mods['des'] ?? 0) >= 0
                                        ? '+${mods['des'] ?? 0}'
                                        : '${mods['des'] ?? 0}')),
                          ],
                        );

                        final savesCard =
                            _buildListCard('Tiradas de Salvación', [
                          _buildListItem(
                              'Fuerza',
                              DndRules.formatModifier(
                                  c.savingThrowBonus('fue')),
                              isProficient: saves['fue'] == true),
                          _buildListItem(
                              'Destreza',
                              DndRules.formatModifier(
                                  c.savingThrowBonus('des')),
                              isProficient: saves['des'] == true),
                          _buildListItem(
                              'Constitución',
                              DndRules.formatModifier(
                                  c.savingThrowBonus('con')),
                              isProficient: saves['con'] == true),
                          _buildListItem(
                              'Inteligencia',
                              DndRules.formatModifier(
                                  c.savingThrowBonus('int')),
                              isProficient: saves['int'] == true),
                          _buildListItem(
                              'Sabiduría',
                              DndRules.formatModifier(
                                  c.savingThrowBonus('sab')),
                              isProficient: saves['sab'] == true),
                          _buildListItem(
                              'Carisma',
                              DndRules.formatModifier(
                                  c.savingThrowBonus('car')),
                              isProficient: saves['car'] == true),
                        ]);

                        final skillsCard = _buildListCard('Habilidades', [
                          for (final entry in DndRules.skills.entries)
                            _buildListItem(
                                '${entry.value.name} (${entry.value.attribute.toUpperCase()})${c.hasExpertise(entry.key) ? " · Pericia" : ""}',
                                DndRules.formatModifier(
                                    c.skillBonus(entry.key)),
                                isProficient:
                                    c.isSkillProficient(entry.key)),
                        ]);

                        return SingleChildScrollView(
                          padding: EdgeInsets.all(isNarrow ? 12 : 20),
                          child: ContentWidth(
                            maxWidth: 1000,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                        child: _buildStatBox('FUE',
                                            stats['fue'] ?? 10,
                                            mods['fue'] ?? 0,
                                            isNarrow: isNarrow)),
                                    Expanded(
                                        child: _buildStatBox('DES',
                                            stats['des'] ?? 10,
                                            mods['des'] ?? 0,
                                            isNarrow: isNarrow)),
                                    Expanded(
                                        child: _buildStatBox('CON',
                                            stats['con'] ?? 10,
                                            mods['con'] ?? 0,
                                            isNarrow: isNarrow)),
                                    Expanded(
                                        child: _buildStatBox('INT',
                                            stats['int'] ?? 10,
                                            mods['int'] ?? 0,
                                            isNarrow: isNarrow)),
                                    Expanded(
                                        child: _buildStatBox('SAB',
                                            stats['sab'] ?? 10,
                                            mods['sab'] ?? 0,
                                            isNarrow: isNarrow)),
                                    Expanded(
                                        child: _buildStatBox('CAR',
                                            stats['car'] ?? 10,
                                            mods['car'] ?? 0,
                                            isNarrow: isNarrow)),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (isNarrow) ...[
                                  combatCards,
                                  const SizedBox(height: 16),
                                  savesCard,
                                  skillsCard,
                                ] else
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          children: [
                                            combatCards,
                                            const SizedBox(height: 16),
                                            savesCard,
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(child: skillsCard),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // TAB 2: Información General
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 720;
                        final infoCard = _buildListCard('Datos del Personaje', [
                          ListTile(
                              title: const Text('Alineamiento',
                                  style: TextStyle(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(bg['alignment'] ?? '-')),
                          ListTile(
                              title: const Text('Velocidad (ft)',
                                  style: TextStyle(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.bold)),
                              subtitle: _buildEditableText(
                                  '${c.sheet['speed'] ?? 30}', _speedCtrl)),
                        ]);

                        final appearanceCard = _buildListCard('Apariencia', [
                          Center(
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: AppColors.gold, width: 4),
                                borderRadius: BorderRadius.circular(8),
                                color: AppColors.bgStat,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: NetworkAvatar(
                                  url: c.avatarUrl,
                                  width: 192,
                                  height: 192,
                                  placeholder: const Icon(Icons.person,
                                      size: 100, color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                          if (_isEditing)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: TextField(
                                controller: _avatarCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'URL de imagen (avatar)',
                                  hintText: 'https://...',
                                  isDense: true,
                                ),
                              ),
                            ),
                        ]);

                        return SingleChildScrollView(
                          padding: EdgeInsets.all(isNarrow ? 12 : 20),
                          child: ContentWidth(
                            maxWidth: 1000,
                            child: isNarrow
                                ? Column(
                                    children: [infoCard, appearanceCard],
                                  )
                                : Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: infoCard),
                                      const SizedBox(width: 20),
                                      Expanded(child: appearanceCard),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),

                    // TAB 3: Trasfondo
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 720;
                        final col1 = [
                          _buildListCard('Historia', [
                            _buildEditableText(
                                bg['history'] ?? '', _historyCtrl,
                                maxLines: 5)
                          ]),
                          _buildListCard('Descripción Física', [
                            _buildEditableText(
                                bg['physical'] ?? '', _physicalCtrl,
                                maxLines: 3)
                          ]),
                        ];

                        final col2 = [
                          _buildListCard('Ideales', [
                            _buildEditableText(
                                bg['ideals'] ?? '', _idealsCtrl,
                                maxLines: 2)
                          ]),
                          _buildListCard('Vínculos', [
                            _buildEditableText(
                                bg['bonds'] ?? '', _bondsCtrl,
                                maxLines: 2)
                          ]),
                          _buildListCard('Defectos', [
                            _buildEditableText(
                                bg['flaws'] ?? '', _flawsCtrl,
                                maxLines: 2)
                          ]),
                        ];

                        return SingleChildScrollView(
                          padding: EdgeInsets.all(isNarrow ? 12 : 20),
                          child: ContentWidth(
                            maxWidth: 1000,
                            child: isNarrow
                                ? Column(children: [...col1, ...col2])
                                : Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: Column(children: col1)),
                                      const SizedBox(width: 20),
                                      Expanded(child: Column(children: col2)),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),

                    // TAB 4: Rasgos
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 720;
                        return SingleChildScrollView(
                          padding: EdgeInsets.all(isNarrow ? 12 : 20),
                          child: ContentWidth(
                            maxWidth: 1000,
                            child: _buildListCard(
                              'Rasgos de Raza y Clase',
                              _buildFeaturesList(c),
                            ),
                          ),
                        );
                      },
                    ),

                    // TAB 5: Equipo
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 720;
                        return SingleChildScrollView(
                          padding: EdgeInsets.all(isNarrow ? 12 : 20),
                          child: ContentWidth(
                            maxWidth: 1000,
                            child: _buildListCard(
                                'Equipamiento',
                                eq.isEmpty
                                    ? [
                                        const Text('Mochila vacía.',
                                            style:
                                                TextStyle(color: Colors.grey))
                                      ]
                                    : eq
                                        .map((item) => Text('• $item',
                                            style: const TextStyle(
                                                height: 1.5)))
                                        .toList()),
                          ),
                        );
                      },
                    ),

                    // TAB 6: Acciones
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 720;
                        return SingleChildScrollView(
                          padding: EdgeInsets.all(isNarrow ? 12 : 20),
                          child: ContentWidth(
                            maxWidth: 1000,
                            child: _buildListCard('Acciones en Combate', [
                              const Text(
                                  'Lista rápida de lo que puedes hacer en tu turno:',
                                  style: TextStyle(
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic)),
                              const SizedBox(height: 10),
                              const Text(
                                  '• Acción Común (Atacar, Lanzar Conjuro, Correr, Esquivar, Esconderse, Ayudar)',
                                  style: TextStyle(height: 1.5)),
                              const SizedBox(height: 10),
                              const Text(
                                  '• Acción Adicional (Depende de clase/arma)',
                                  style: TextStyle(height: 1.5)),
                            ]),
                          ),
                        );
                      },
                    ),

                    // TAB 7: Conjuros
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 720;
                        return SingleChildScrollView(
                          padding: EdgeInsets.all(isNarrow ? 12 : 20),
                          child: ContentWidth(
                            maxWidth: 1000,
                            child: _buildListCard('Conjuros y Magia', [
                              const Text('No conoces ningún conjuro.',
                                  style: TextStyle(color: Colors.grey))
                            ]),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFeaturesList(Character c) {
    final subclass = (c.sheet['subclass'] as String? ?? '').trim();
    final rawFeatures = (c.sheet['features'] as List<dynamic>?) ?? [];
    final items = <Widget>[];

    if (subclass.isNotEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Subclase activa: $subclass',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.accent),
          ),
        ),
      );
    }

    if (rawFeatures.isEmpty) {
      items.add(const Text(
        '• Visión en la oscuridad (Racial)\n• Ataque Extra (Clase)',
        style: TextStyle(height: 1.5),
      ));
      return items;
    }

    for (final raw in rawFeatures) {
      if (raw is Map) {
        final name = raw['name']?.toString() ?? 'Rasgo';
        final source = raw['source']?.toString() ?? '';
        final level = raw['level'] ?? 1;
        final desc = raw['description']?.toString() ?? '';
        items.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• $name ($source - Nivel $level)',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.accent),
                ),
                if (desc.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 2),
                    child: Text(desc, style: const TextStyle(height: 1.4)),
                  ),
              ],
            ),
          ),
        );
      } else {
        items.add(Text('• $raw', style: const TextStyle(height: 1.5)));
      }
    }
    return items;
  }
}

