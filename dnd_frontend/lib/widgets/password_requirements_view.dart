import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class PasswordRule {
  final String label;
  final bool Function(String) validator;

  const PasswordRule({
    required this.label,
    required this.validator,
  });
}

class PasswordRequirementsView extends StatelessWidget {
  final String password;
  final String? confirmPassword;

  const PasswordRequirementsView({
    super.key,
    required this.password,
    this.confirmPassword,
  });

  static final List<PasswordRule> rules = [
    PasswordRule(
      label: 'Mínimo 8 caracteres',
      validator: (p) => p.length >= 8,
    ),
    PasswordRule(
      label: 'Una mayúscula (A-Z)',
      validator: (p) => RegExp(r'[A-Z]').hasMatch(p),
    ),
    PasswordRule(
      label: 'Una minúscula (a-z)',
      validator: (p) => RegExp(r'[a-z]').hasMatch(p),
    ),
    PasswordRule(
      label: 'Un número (0-9)',
      validator: (p) => RegExp(r'[0-9]').hasMatch(p),
    ),
    PasswordRule(
      label: r'Un carácter especial (!@#$...)',
      validator: (p) => RegExp(r'[!@#$%^&*(),.?":{}|<>\-_=+[\]\\/;`~]').hasMatch(p),
    ),
  ];

  static bool isPasswordSecure(String password) {
    return rules.every((r) => r.validator(password));
  }

  int get _fulfilledCount => rules.where((r) => r.validator(password)).length;

  double get _strengthRatio => rules.isEmpty ? 0 : _fulfilledCount / rules.length;

  Color get _strengthColor {
    final count = _fulfilledCount;
    if (count <= 1) return const Color(0xFFD32F2F); // Rojo
    if (count <= 2) return const Color(0xFFE65100); // Naranja
    if (count <= 3) return const Color(0xFFF57F17); // Ámbar
    if (count <= 4) return const Color(0xFF2E7D32); // Verde
    return AppColors.accent; // Excelente / Cumplido
  }

  String get _strengthLabel {
    final count = _fulfilledCount;
    if (password.isEmpty) return 'Seguridad de la contraseña';
    if (count <= 1) return 'Muy débil';
    if (count <= 2) return 'Débil';
    if (count <= 3) return 'Moderada';
    if (count <= 4) return 'Fuerte';
    return '¡Excelente y segura!';
  }

  @override
  Widget build(BuildContext context) {
    final hasConfirm = confirmPassword != null;
    final passwordsMatch = hasConfirm &&
        confirmPassword!.isNotEmpty &&
        password.isNotEmpty &&
        password == confirmPassword;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de fortaleza interactiva
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Requisitos de seguridad',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: password.isEmpty ? AppColors.muted : _strengthColor,
                  fontFamily: 'Georgia',
                ),
                child: Text(_strengthLabel),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: password.isEmpty ? 0.0 : _strengthRatio,
              minHeight: 5,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
            ),
          ),
          const SizedBox(height: 10),

          // Cuadrícula / Wrap responsivo de casillas de validación
          LayoutBuilder(
            builder: (context, constraints) {
              // Si el ancho permite 2 columnas (>300px), distribuimos en dos columnas
              final isTwoColumn = constraints.maxWidth >= 310;
              final itemWidth = isTwoColumn
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  ...rules.map((rule) {
                    final passed = rule.validator(password);
                    return SizedBox(
                      width: itemWidth,
                      child: _RuleCheckItem(
                        label: rule.label,
                        fulfilled: passed,
                      ),
                    );
                  }),
                  if (hasConfirm && confirmPassword!.isNotEmpty)
                    SizedBox(
                      width: itemWidth,
                      child: _RuleCheckItem(
                        label: 'Las contraseñas coinciden',
                        fulfilled: passwordsMatch,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RuleCheckItem extends StatelessWidget {
  final String label;
  final bool fulfilled;

  const _RuleCheckItem({
    required this.label,
    required this.fulfilled,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: fulfilled
            ? AppColors.success.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: fulfilled
              ? AppColors.success.withValues(alpha: 0.3)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
            child: Icon(
              fulfilled ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              key: ValueKey<bool>(fulfilled),
              size: 17,
              color: fulfilled ? AppColors.success : AppColors.muted.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'Georgia',
                fontWeight: fulfilled ? FontWeight.w600 : FontWeight.normal,
                color: fulfilled ? AppColors.success : AppColors.muted,
              ),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
