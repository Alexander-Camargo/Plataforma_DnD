import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/api/api_client.dart';
import '../core/data/dnd_rules.dart';
import '../core/theme/app_theme.dart';
import '../widgets/main_drawer.dart';

class CreateCharacterScreen extends StatefulWidget {
  const CreateCharacterScreen({super.key});

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
  final Map<String, int> _baseStats = {for (final k in DndRules.statNames.keys) k: 8};

  // Paso 3: trasfondo
  final _avatarCtrl = TextEditingController();
  final _historyCtrl = TextEditingController();
  final _idealsCtrl = TextEditingController();
  final _bondsCtrl = TextEditingController();
  final _flawsCtrl = TextEditingController();

  @override
  void dispose() {
    for (final c in [_nameCtrl, _avatarCtrl, _historyCtrl, _idealsCtrl, _bondsCtrl, _flawsCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------- Reglas ----------
  int get _pointsSpent =>
      _baseStats.values.fold(0, (sum, v) => sum + (DndRules.pointCosts[v] ?? 0));
  int get _pointsRemaining => DndRules.pointBudget - _pointsSpent;

  int _racial(String stat) => DndRules.racialBonuses[_race]?[stat] ?? 0;
  int _finalStat(String stat) => _baseStats[stat]! + _racial(stat);

  int get _maxHp {
    final die = DndRules.classInfo(_class)?.hitDie ?? 8;
    final hp = die + DndRules.modifier(_finalStat('con'));
    return hp < 1 ? 1 : hp;
  }

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

    setState(() => _isSaving = true);
    try {
      final info = DndRules.classInfo(_class);
      final stats = {for (final k in _baseStats.keys) k: _finalStat(k)};
      final mods = {for (final e in stats.entries) e.key: DndRules.modifier(e.value)};

      await _api.post('/characters/', {
        'name': _nameCtrl.text.trim(),
        'race': _race,
        'class_slug': _class.toLowerCase(),
        'level': 1,
        'avatar_url': _avatarCtrl.text.trim().isEmpty ? null : _avatarCtrl.text.trim(),
        'sheet': {
          'stats': stats,
          'modifiers': mods,
          'saves': {for (final s in info?.saves ?? <String>[]) s: true},
          'skills': {},
          'ac': 10 + mods['des']!,
          'hp': _maxHp,
          'initiative': mods['des'],
          'speed': DndRules.speedFor(_race),
          'attacks': [],
          'features': [],
          'equipment': List<String>.from(info?.equipment ?? const []),
          'spells': [],
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
    final canAdd = base < 15 &&
        _pointsRemaining >= (DndRules.pointCosts[base + 1]! - DndRules.pointCosts[base]!);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DndRules.statNames[key]} (${key.toUpperCase()})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                if (racial > 0)
                  Text('+$racial racial ($_race)',
                      style: const TextStyle(color: AppColors.success, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: AppColors.accent),
            onPressed: base > 8 ? () => setState(() => _baseStats[key] = base - 1) : null,
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
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.accent)),
                Text(_modText(DndRules.modifier(_finalStat(key))),
                    style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.accent),
            onPressed: canAdd ? () => setState(() => _baseStats[key] = base + 1) : null,
          ),
        ],
      ),
    );
  }

  String _modText(int m) => m >= 0 ? '+$m' : '$m';

  Widget _dropdown(String label, String value, List<String> items, ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: (v) {
        if (v != null) setState(() => onChanged(v));
      },
    );
  }

  Widget _field(TextEditingController ctrl, String label, {int lines = 1, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        maxLines: lines,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }

  Widget _summaryLine(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );

  Step _step(int index, String title, Widget content) {
    return Step(
      title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      content: SheetCard(margin: EdgeInsets.zero, children: [content]),
      isActive: _currentStep >= index,
      state: _currentStep > index ? StepState.complete : StepState.indexed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = DndRules.classInfo(_class);
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
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _isSaving ? null : details.onStepContinue,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_currentStep == _lastStep ? 'Guardar personaje' : 'Siguiente'),
                ),
                const SizedBox(width: 12),
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
                  _dropdown('Raza', _race, DndRules.races, (v) => _race = v),
                  const SizedBox(height: 14),
                  _dropdown('Clase', _class, DndRules.classes.keys.toList(), (v) => _class = v),
                  const SizedBox(height: 14),
                  _dropdown('Alineamiento', _alignment, DndRules.alignments, (v) => _alignment = v),
                ],
              ),
            ),
            _step(
              1,
              'II. Atributos base',
              Column(
                children: [
                  Text(
                    'Puntos disponibles: $_pointsRemaining / ${DndRules.pointBudget}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _pointsRemaining == 0 ? AppColors.success : AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sistema de compra oficial: cada atributo va de 8 a 15. '
                    'El bonificador racial se suma automáticamente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.muted),
                  ),
                  const Divider(height: 24),
                  for (final k in stats) _statRow(k),
                ],
              ),
            ),
            _step(
              2,
              'III. Trasfondo y apariencia',
              Column(
                children: [
                  _field(_avatarCtrl, 'URL de imagen (avatar)', hint: 'https://...'),
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
                  _summaryLine('Nombre', _nameCtrl.text.trim().isEmpty ? 'Sin nombre' : _nameCtrl.text.trim()),
                  _summaryLine('Raza y clase', '$_race $_class (Nivel 1)'),
                  _summaryLine('Alineamiento', _alignment),
                  _summaryLine('Puntos de golpe', '$_maxHp'),
                  _summaryLine('Velocidad', '${DndRules.speedFor(_race)} ft'),
                  _summaryLine(
                    'Atributos',
                    stats.map((k) => '${k.toUpperCase()} ${_finalStat(k)}').join(' · '),
                  ),
                  _summaryLine(
                    'Salvaciones',
                    (info?.saves ?? []).map((s) => DndRules.statNames[s]).join(', '),
                  ),
                  _summaryLine('Equipo inicial', (info?.equipment ?? []).join(', ')),
                  const SizedBox(height: 10),
                  const Text(
                    'Podrás editar el inventario, conjuros y demás desde tu hoja de personaje.',
                    style: TextStyle(color: AppColors.muted, fontStyle: FontStyle.italic),
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
