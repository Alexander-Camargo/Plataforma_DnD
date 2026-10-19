/*
Archivo: level_up_dialog.dart
Propósito: Diálogo interactivo de subida de nivel según D&D 5e (selección de PG por media fija o tirada de dado, Mejora de Característica ASI y subclase).
Creador: Alexander Camargo
Modificaciones / Actualizaciones:
- 2026-10-18 [Alexander Camargo]: Creación del diálogo guiado de subida de nivel 5e para el Hito 3.1.
*/

import 'dart:math';
import 'package:flutter/material.dart';
import '../core/data/dnd_rules.dart';
import '../core/theme/app_theme.dart';
import '../models/models.dart';

class LevelUpDialog extends StatefulWidget {
  final Character character;
  const LevelUpDialog({super.key, required this.character});

  @override
  State<LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends State<LevelUpDialog> {
  bool _useAverageHp = true;
  late int _rolledDie;
  final Map<String, int> _asi = {};
  final TextEditingController _subclassCtrl = TextEditingController();

  int get _targetLevel => widget.character.level + 1;
  ClassInfo get _classInfo =>
      DndRules.classInfo(widget.character.classSlug) ??
      const ClassInfo(8, [], []);
  int get _hitDie => _classInfo.hitDie;
  bool get _hasAsi =>
      DndRules.hasAsi(widget.character.classSlug, _targetLevel);
  bool get _needsSubclass {
    final existing =
        (widget.character.sheet['subclass'] as String? ?? '').trim();
    return existing.isEmpty && _targetLevel >= _classInfo.subclassLevel;
  }

  int get _asiSpent => _asi.values.fold(0, (a, b) => a + b);

  int _baseStat(String key) =>
      ((widget.character.sheet['stats'] as Map?)?[key] as num?)?.toInt() ?? 10;

  int _newStat(String key) => _baseStat(key) + (_asi[key] ?? 0);

  int get _hpGainPreview {
    final oldConMod = DndRules.modifier(_baseStat('con'));
    final newConMod = DndRules.modifier(_newStat('con'));
    final dieVal = _useAverageHp ? (_hitDie ~/ 2) + 1 : _rolledDie;
    final retro = max(0, (newConMod - oldConMod) * widget.character.level);
    final subraceId =
        (widget.character.sheet['creation'] as Map?)?['subrace_id'];
    final dwarfBonus = subraceId == 'hill_dwarf' ? 1 : 0;
    return max(1, dieVal + newConMod) + dwarfBonus + retro;
  }

  @override
  void initState() {
    super.initState();
    _rolledDie = (_hitDie ~/ 2) + 1;
  }

  @override
  void dispose() {
    _subclassCtrl.dispose();
    super.dispose();
  }

  void _adjustAsi(String key, int delta) {
    final current = _asi[key] ?? 0;
    final next = current + delta;
    if (next < 0 || next > 2) return;
    if (delta > 0 && (_asiSpent >= 2 || _newStat(key) >= 20)) return;
    setState(() {
      if (next == 0) {
        _asi.remove(key);
      } else {
        _asi[key] = next;
      }
    });
  }

  void _submit() {
    final payload = <String, dynamic>{};
    if (!_useAverageHp) {
      payload['hp_roll'] = _rolledDie;
    }
    if (_hasAsi && _asi.isNotEmpty) {
      payload['asi'] = Map<String, int>.from(_asi);
    }
    final subclass = _subclassCtrl.text.trim();
    if (_needsSubclass && subclass.isNotEmpty) {
      payload['subclass'] = subclass;
    }
    Navigator.of(context).pop(payload);
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = !_hasAsi || _asiSpent == 0 || _asiSpent == 2;
    return AlertDialog(
      title: Text(
        'Subir a Nivel $_targetLevel',
        style: const TextStyle(
            fontWeight: FontWeight.bold, color: AppColors.accent),
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHpSection(),
              if (_needsSubclass) ...[
                const SizedBox(height: 16),
                _buildSubclassSection(),
              ],
              if (_hasAsi) ...[
                const SizedBox(height: 16),
                _buildAsiSection(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: canConfirm ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.bgDark,
          ),
          child: const Text('Confirmar Subida'),
        ),
      ],
    );
  }

  Widget _buildHpSection() {
    final fixedDie = (_hitDie ~/ 2) + 1;
    final currentHp = (widget.character.sheet['hp'] as num?)?.toInt() ?? 10;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgStat,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Puntos de Golpe (Dado d$_hitDie)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text('Media fija ($fixedDie)'),
                selected: _useAverageHp,
                onSelected: (_) => setState(() => _useAverageHp = true),
              ),
              ChoiceChip(
                label: const Text('Tirar dado'),
                selected: !_useAverageHp,
                onSelected: (_) => setState(() => _useAverageHp = false),
              ),
            ],
          ),
          if (!_useAverageHp) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Resultado del d'),
                Text('$_hitDie: '),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _rolledDie,
                  items: List.generate(
                    _hitDie,
                    (i) => DropdownMenuItem(
                        value: i + 1, child: Text('${i + 1}')),
                  ),
                  onChanged: (v) {
                    if (v != null) setState(() => _rolledDie = v);
                  },
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => setState(
                      () => _rolledDie = Random().nextInt(_hitDie) + 1),
                  icon: const Icon(Icons.casino, size: 16),
                  label: const Text('Lanzar'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'PG Máximos: $currentHp → ${currentHp + _hpGainPreview} (+$_hpGainPreview PG)',
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.accent),
          ),
        ],
      ),
    );
  }

  Widget _buildSubclassSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _classInfo.subclassLabel,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _subclassCtrl,
          decoration: InputDecoration(
            hintText: 'Ej. Campeón, Evocación, Dominio de la Vida...',
            labelText: 'Elegir ${_classInfo.subclassLabel}',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildAsiSection() {
    final remaining = 2 - _asiSpent;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgStat,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mejora de Característica (ASI)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Puntos: $remaining / 2',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: remaining == 0 ? Colors.green.shade700 : AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Reparte +2 a una característica o +1 a dos características (máximo 20).',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          ...DndRules.statNames.entries.map((entry) {
            final key = entry.key;
            final delta = _asi[key] ?? 0;
            final score = _newStat(key);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text('${entry.value} (${key.toUpperCase()})')),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: delta > 0 ? () => _adjustAsi(key, -1) : null,
                  ),
                  SizedBox(
                    width: 54,
                    child: Text(
                      delta > 0 ? '$score (+$delta)' : '$score',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight:
                            delta > 0 ? FontWeight.bold : FontWeight.normal,
                        color: delta > 0 ? AppColors.accent : AppColors.text,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    onPressed: (_asiSpent < 2 && score < 20)
                        ? () => _adjustAsi(key, 1)
                        : null,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
