import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/api/api_client.dart';
import '../models/creation_catalog.dart';
import '../core/data/dnd_rules.dart';
import '../core/theme/app_theme.dart';
import '../widgets/main_drawer.dart';
import '../widgets/quick_help.dart';
import '../core/data/tutorial_topics.dart';

class CreateCharacterScreen extends StatefulWidget {
  final CreationCatalog? catalog;
  const CreateCharacterScreen({super.key, this.catalog});

  @override
  State<CreateCharacterScreen> createState() => _CreateCharacterScreenState();
}

class _CreateCharacterScreenState extends State<CreateCharacterScreen> {
  static const int _lastStep = 3;

  final ApiClient _api = ApiClient();
  int _currentStep = 0;
  bool _isSaving = false;

  // Paso 1: identidad
  final _nameCtrl = TextEditingController();
  String _race = 'Humano';
  String _class = 'Guerrero';
  String _alignment = 'Verdadero Neutral';

  // Paso 2: atributos (compra de puntos)
  final Map<String, int> _baseStats = {
    for (final k in DndRules.statNames.keys) k: 8
  };

  // Paso 3: trasfondo
  final _avatarCtrl = TextEditingController();
  final _historyCtrl = TextEditingController();
  final _idealsCtrl = TextEditingController();
  final _bondsCtrl = TextEditingController();
  final _flawsCtrl = TextEditingController();

  CreationCatalog? _rules;
  String? _rulesError;
  String? _subrace;
  String _backgroundId = 'acolyte';
  final Set<String> _racialAbilities = {};
  final Set<String> _classSkills = {};
  final Set<String> _raceSkills = {};
  final Set<String> _replacementSkills = {};
  final Set<String> _expertise = {};

  @override
  void initState() {
    super.initState();
    _rules = widget.catalog;
    if (_rules == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadRules());
    }
  }

  Future<void> _loadRules() async {
    setState(() => _rulesError = null);
    try {
      final data = await _api.get('/rules/creation');
      if (!mounted) return;
      setState(() =>
          _rules = CreationCatalog.fromJson(Map<String, dynamic>.from(data)));
    } on ApiException catch (error) {
      if (mounted) setState(() => _rulesError = error.message);
    }
  }

  Map<String, dynamic> get _raceRule =>
      _rules!.races.firstWhere((item) => item['name'] == _race);
  Map<String, dynamic> get _classRule =>
      _rules!.classes.firstWhere((item) => item['name'] == _class);
  Map<String, dynamic> get _backgroundRule =>
      _rules!.backgrounds.firstWhere((item) => item['id'] == _backgroundId);
  List<Map<String, dynamic>> get _subraces => (_raceRule['subraces'] as List)
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
  Map<String, dynamic>? get _subraceRule {
    for (final item in _subraces) {
      if (item['id'] == _subrace) return item;
    }
    return null;
  }

  List<String> get _grants => [
        ...List<String>.from(_raceRule['fixed_skills']),
        ..._classSkills,
        ..._raceSkills,
        ...List<String>.from(_backgroundRule['skills']),
      ];
  int get _duplicateCount => _grants.length - _grants.toSet().length;
  Set<String> get _proficientSkills => {..._grants, ..._replacementSkills};
  String _skillName(String key) =>
      _rules!.skills.firstWhere((item) => item['key'] == key)['name'];

  void _changeRace(String value) {
    _race = value;
    _subrace = _subraces.isEmpty ? null : _subraces.first['id'];
    _racialAbilities.clear();
    _raceSkills.clear();
    _replacementSkills.clear();
    _expertise.clear();
  }

  Widget _helpHeading(String title, TutorialTopic topic) => Row(children: [
        Flexible(
            child: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.accent))),
        QuickHelp(topic: topic),
      ]);

  Widget _grantedSkills(String title, List<String> skills) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _helpHeading(title, topicForLabel('Competencias')!),
          Wrap(spacing: 12, children: [
            for (final skill in skills)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(child: Text(_skillName(skill))),
                QuickHelp(topic: topicForSkill(skill)!),
              ]),
          ]),
        ],
      );

  Widget _choices(String title, Set<String> selected, List<String> options,
      int count, String Function(String) label) {
    if (count == 0) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      _helpHeading(
          '$title (${selected.length}/$count)',
          selected == _racialAbilities
              ? topicForLabel('Atributos')!
              : selected == _expertise
                  ? topicForLabel('Pericia')!
                  : topicForLabel('Competencias')!),
      for (final option in options)
        Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Row(children: [
                Flexible(child: Text(label(option))),
                if (topicForSkill(option) != null)
                  QuickHelp(topic: topicForSkill(option)!),
              ]),
              value: selected.contains(option),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: selected.length >= count && !selected.contains(option)
                  ? null
                  : (enabled) {
                      setState(() {
                        if (enabled == true) {
                          selected.add(option);
                        } else {
                          selected.remove(option);
                        }
                        if (selected == _classSkills ||
                            selected == _raceSkills) {
                          _replacementSkills.clear();
                        }
                        if (selected == _classSkills ||
                            selected == _raceSkills ||
                            selected == _replacementSkills) {
                          _expertise.clear();
                        }
                      });
                    },
            )),
    ]);
  }

  String? _creationError() {
    if (_subraces.isNotEmpty && _subraceRule == null) {
      return 'Elige una subraza.';
    }
    if (_racialAbilities.length != _raceRule['bonus_count']) {
      return 'Elige los bonificadores raciales del semielfo.';
    }
    if (_classSkills.length != _classRule['skill_count']) {
      return 'Elige todas las competencias de tu clase.';
    }
    if (_raceSkills.length != _raceRule['skill_count']) {
      return 'Elige todas las competencias de tu raza.';
    }
    if (_replacementSkills.length != _duplicateCount) {
      return 'Sustituye las competencias repetidas.';
    }
    if (_expertise.length != _classRule['expertise_count']) {
      return 'Elige las pericias de tu clase.';
    }
    return null;
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _avatarCtrl,
      _historyCtrl,
      _idealsCtrl,
      _bondsCtrl,
      _flawsCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // Las cifras de vista previa usan el catálogo; el servidor las valida al guardar.
  int get _pointsSpent => _baseStats.values
      .fold(0, (sum, value) => sum + (_rules!.pointCosts[value] ?? 0));
  int get _pointsRemaining => _rules!.pointBudget - _pointsSpent;
  int _racial(String stat) =>
      ((_raceRule['bonuses'] as Map)[stat] as int? ?? 0) +
      ((_subraceRule?['bonuses'] as Map?)?[stat] as int? ?? 0) +
      (_racialAbilities.contains(stat) ? _raceRule['bonus_amount'] as int : 0);
  int _finalStat(String stat) => _baseStats[stat]! + _racial(stat);
  int get _maxHp {
    final hp =
        (_classRule['hit_die'] as int) + DndRules.modifier(_finalStat('con'));
    return (hp < 1 ? 1 : hp) + (_subraceRule?['hp_per_level'] as int? ?? 0);
  }

  int get _initialAc {
    final normal = 10 + DndRules.modifier(_finalStat('des'));
    final defense = 10 +
        List<String>.from(_classRule['unarmored_abilities']).fold<int>(
            0, (sum, key) => sum + DndRules.modifier(_finalStat(key)));
    return defense > normal ? defense : normal;
  }

  int get _speed => (_subraceRule?['speed'] ?? _raceRule['speed']) as int;
  int _skillBonus(Map<String, dynamic> skill) =>
      DndRules.modifier(_finalStat(skill['ability'])) +
      (_proficientSkills.contains(skill['key'])
          ? DndRules.proficiencyBonus(1) *
              (_expertise.contains(skill['key']) ? 2 : 1)
          : 0);

  // ---------- Navegación del stepper ----------
  void _next() {
    if (_currentStep == 0 && _nameCtrl.text.trim().isEmpty) {
      _snack('Escribe el nombre del personaje.');
      return;
    }
    if (_currentStep == _lastStep) {
      _save();
    } else {
      setState(() => _currentStep += 1);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack('El nombre es obligatorio.');
      setState(() => _currentStep = 0);
      return;
    }
    if (_pointsRemaining < 0) {
      _snack('Has gastado demasiados puntos de atributo.');
      setState(() => _currentStep = 1);
      return;
    }

    final error = _creationError();
    if (error != null) {
      _snack(error);
      setState(() => _currentStep = 1);
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _api.post('/characters/', {
        'name': _nameCtrl.text.trim(),
        'race': _race,
        'subrace': _subrace,
        'class_slug': _class.toLowerCase(),
        'level': 1,
        'avatar_url':
            _avatarCtrl.text.trim().isEmpty ? null : _avatarCtrl.text.trim(),
        'creation': {
          'base_stats': _baseStats,
          'racial_abilities': _racialAbilities.toList(),
          'class_skills': _classSkills.toList(),
          'race_skills': _raceSkills.toList(),
          'background_id': _backgroundId,
          'replacement_skills': _replacementSkills.toList(),
          'expertise': _expertise.toList(),
        },
        'sheet': {
          'background': {
            'alignment': _alignment,
            'history': _historyCtrl.text,
            'ideals': _idealsCtrl.text,
            'bonds': _bondsCtrl.text,
            'flaws': _flawsCtrl.text,
          },
        },
      });

      if (!mounted) return;
      _snack('¡Personaje forjado con éxito!');
      context.go('/my-characters');
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ---------- UI ----------
  Widget _statRow(String key) {
    final base = _baseStats[key]!;
    final racial = _racial(key);
    final canAdd = base < _rules!.baseMax &&
        _pointsRemaining >=
            (_rules!.pointCosts[base + 1]! - _rules!.pointCosts[base]!);

    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                '${DndRules.statNames[key]} (${key.toUpperCase()})',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            QuickHelp(topic: topicForLabel(key)!),
          ],
        ),
        if (racial > 0)
          Text('+$racial racial ($_race)',
              style: const TextStyle(color: AppColors.success, fontSize: 12)),
      ],
    );
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Reducir ${DndRules.statNames[key]}',
          icon:
              const Icon(Icons.remove_circle_outline, color: AppColors.accent),
          onPressed: base > _rules!.baseMin
              ? () => setState(() => _baseStats[key] = base - 1)
              : null,
        ),
        Container(
          width: 64,
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.bgStat,
            border: Border.all(color: AppColors.borderStat, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text('${_finalStat(key)}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent)),
              Text(_modText(DndRules.modifier(_finalStat(key))),
                  style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Aumentar ${DndRules.statNames[key]}',
          icon: const Icon(Icons.add_circle_outline, color: AppColors.accent),
          onPressed:
              canAdd ? () => setState(() => _baseStats[key] = base + 1) : null,
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label,
              Align(alignment: Alignment.centerRight, child: controls)
            ],
          );
        }
        return Row(children: [Expanded(child: label), controls]);
      }),
    );
  }

  String _modText(int m) => m >= 0 ? '+$m' : '$m';

  Widget _dropdown(String label, String value, List<String> items,
      ValueChanged<String> onChanged) {
    return HelpField(
      topic: topicForLabel(label),
      child: DropdownButtonFormField<String>(
        key: ValueKey("$label:$value"),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: items
            .map((i) => DropdownMenuItem(value: i, child: Text(i)))
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() => onChanged(v));
        },
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {int lines = 1, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: HelpField(
        topic: topicForLabel(label),
        child: TextField(
          controller: ctrl,
          maxLines: lines,
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
      ),
    );
  }

  Widget _summaryLine(String label, String value, {TutorialTopic? helpTopic}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.accent, fontWeight: FontWeight.bold)),
            ),
            Expanded(child: Text(value)),
            if ((helpTopic ?? topicForLabel(label)) != null)
              QuickHelp(topic: (helpTopic ?? topicForLabel(label))!),
          ],
        ),
      );

  Step _step(int index, String title, Widget content) {
    return Step(
      title: Text(title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      content: SheetCard(margin: EdgeInsets.zero, children: [content]),
      isActive: _currentStep >= index,
      state: _currentStep > index ? StepState.complete : StepState.indexed,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_rules == null) {
      return Scaffold(
          appBar: AppBar(title: const Text("Forjar Aventurero")),
          body: Center(
              child: _rulesError == null
                  ? const CircularProgressIndicator()
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_rulesError!),
                      TextButton(
                          onPressed: _loadRules,
                          child: const Text("Reintentar"))
                    ])));
    }
    final stats = _baseStats.keys.toList();

    return Scaffold(
      drawer: const MainDrawer(),
      appBar: AppBar(title: const Text('Forjar Aventurero')),
      body: ContentWidth(
        maxWidth: 760,
        child: Stepper(
          type: StepperType.vertical,
          currentStep: _currentStep,
          onStepTapped: (i) => setState(() => _currentStep = i),
          onStepContinue: _next,
          onStepCancel: () {
            if (_currentStep > 0) setState(() => _currentStep -= 1);
          },
          controlsBuilder: (context, details) => Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _isSaving ? null : details.onStepContinue,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_currentStep == _lastStep
                          ? 'Guardar personaje'
                          : 'Siguiente'),
                ),
                if (_currentStep > 0)
                  TextButton(
                    onPressed: _isSaving ? null : details.onStepCancel,
                    child: const Text('Volver'),
                  ),
              ],
            ),
          ),
          steps: [
            _step(
              0,
              'I. Identidad',
              Column(
                children: [
                  _field(_nameCtrl, 'Nombre del personaje'),
                  _dropdown(
                      'Raza',
                      _race,
                      _rules!.races
                          .map((item) => item['name'] as String)
                          .toList(),
                      _changeRace),
                  if (_subraces.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _dropdown(
                        'Subraza',
                        _subraceRule?['name'] ?? 'Seleccionar',
                        _subraces
                            .map((item) => item['name'] as String)
                            .toList(), (value) {
                      _subrace = _subraces
                          .firstWhere((item) => item['name'] == value)['id'];
                    }),
                  ],
                  const SizedBox(height: 14),
                  _dropdown(
                      'Clase',
                      _class,
                      _rules!.classes
                          .map((item) => item['name'] as String)
                          .toList(), (v) {
                    _class = v;
                    _classSkills.clear();
                    _replacementSkills.clear();
                    _expertise.clear();
                  }),
                  const SizedBox(height: 14),
                  _dropdown('Alineamiento', _alignment, DndRules.alignments,
                      (v) => _alignment = v),
                ],
              ),
            ),
            _step(
              1,
              'II. Atributos base',
              Column(
                children: [
                  Text(
                    'Puntos disponibles: $_pointsRemaining / ${_rules!.pointBudget}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _pointsRemaining == 0
                          ? AppColors.success
                          : AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sistema de compra oficial: cada atributo va de 8 a 15. '
                    'El bonificador racial se suma automáticamente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontStyle: FontStyle.italic, color: AppColors.muted),
                  ),
                  const Divider(height: 24),
                  for (final k in stats) _statRow(k),
                  const SizedBox(height: 16),
                  const Text(
                      'La clase orienta tus elecciones, pero no añade puntuaciones fijas. Cada competencia añade +2 en nivel 1; la pericia duplica ese bonificador.',
                      style: TextStyle(color: AppColors.muted, height: 1.5)),
                  _choices(
                      'Bonificadores raciales: +1 a dos características distintas',
                      _racialAbilities,
                      List<String>.from(_raceRule['bonus_options']),
                      _raceRule['bonus_count'],
                      (key) => DndRules.statNames[key]!),
                  if ((_raceRule['fixed_skills'] as List).isNotEmpty)
                    _grantedSkills('Competencias raciales',
                        List<String>.from(_raceRule['fixed_skills'])),
                  _choices(
                      'Competencias de clase',
                      _classSkills,
                      List<String>.from(_classRule['skill_options']),
                      _classRule['skill_count'],
                      _skillName),
                  _choices(
                      'Competencias raciales a elegir',
                      _raceSkills,
                      _rules!.skills
                          .map((item) => item['key'] as String)
                          .toList(),
                      _raceRule['skill_count'],
                      _skillName),
                  _choices(
                      'Sustituye competencias repetidas',
                      _replacementSkills,
                      _rules!.skills
                          .map((item) => item['key'] as String)
                          .where((key) => !_grants.contains(key))
                          .toList(),
                      _duplicateCount,
                      _skillName),
                  _choices(
                      'Pericia',
                      _expertise,
                      [
                        ..._proficientSkills,
                        ...List<String>.from(_classRule['expertise_tools'])
                      ],
                      _classRule['expertise_count'],
                      (key) => _rules!.toolLabels[key] ?? _skillName(key)),
                ],
              ),
            ),
            _step(
              2,
              'III. Trasfondo y apariencia',
              Column(
                children: [
                  _dropdown(
                      'Trasfondo de reglas',
                      _backgroundRule['name'],
                      _rules!.backgrounds
                          .map((item) => item['name'] as String)
                          .toList(), (value) {
                    _backgroundId = _rules!.backgrounds
                        .firstWhere((item) => item['name'] == value)['id'];
                    _replacementSkills.clear();
                    _expertise.clear();
                  }),
                  const SizedBox(height: 8),
                  _grantedSkills('Competencias del trasfondo',
                      List<String>.from(_backgroundRule['skills'])),
                  const Text(
                      'Si coincide con una competencia elegida, vuelve a Atributos base y selecciona su sustitución.',
                      style: TextStyle(color: AppColors.muted, height: 1.5)),
                  const SizedBox(height: 14),
                  _field(_avatarCtrl, 'URL de imagen (avatar)',
                      hint: 'https://...'),
                  _field(_historyCtrl, 'Historia del personaje', lines: 3),
                  _field(_idealsCtrl, 'Ideales', lines: 2),
                  _field(_bondsCtrl, 'Vínculos', lines: 2),
                  _field(_flawsCtrl, 'Defectos', lines: 2),
                ],
              ),
            ),
            _step(
              3,
              'IV. Resumen final',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _summaryLine(
                      'Nombre',
                      _nameCtrl.text.trim().isEmpty
                          ? 'Sin nombre'
                          : _nameCtrl.text.trim()),
                  _summaryLine('Raza y clase', '$_race $_class (Nivel 1)'),
                  _summaryLine('Alineamiento', _alignment),
                  _summaryLine('CA sin armadura', '$_initialAc'),
                  _summaryLine('Puntos de golpe', '$_maxHp'),
                  _summaryLine('Velocidad', '$_speed ft'),
                  _summaryLine(
                    'Atributos',
                    stats
                        .map((k) => '${k.toUpperCase()} ${_finalStat(k)}')
                        .join(' · '),
                  ),
                  _summaryLine(
                      'Subraza', _subraceRule?['name'] ?? 'No corresponde'),
                  _summaryLine('Trasfondo', _backgroundRule['name']),
                  _summaryLine(
                      'Competencia', '+${DndRules.proficiencyBonus(1)}'),
                  _summaryLine(
                      'Salvaciones',
                      List<String>.from(_classRule['saves'])
                          .map((key) => DndRules.statNames[key])
                          .join(', ')),
                  for (final skill in _rules!.skills)
                    _summaryLine(
                        skill['name'],
                        '${_skillBonus(skill) >= 0 ? '+' : ''}${_skillBonus(skill)}${_expertise.contains(skill['key']) ? ' · Pericia' : _proficientSkills.contains(skill['key']) ? ' · Competente' : ''}',
                        helpTopic: topicForSkill(skill['key'])),
                  const Text(
                      'La CA inicial es sin armadura. El equipo inicial debe elegirse con el DM y anotarse en la hoja; no se equipa automáticamente.',
                      style: TextStyle(color: AppColors.muted, height: 1.5)),
                  const SizedBox(height: 10),
                  const Text(
                    'Podrás editar el inventario, conjuros y demás desde tu hoja de personaje.',
                    style: TextStyle(
                        color: AppColors.muted, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
