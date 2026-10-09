import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isRegister = false;
  bool _busy = false;
  bool _hidePass = true;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    final error = _isRegister
        ? await auth.register(_userCtrl.text, _emailCtrl.text, _passCtrl.text)
        : await auth.login(_userCtrl.text, _passCtrl.text);

    // Si salió bien, el router redirige solo a la pantalla principal.
    if (mounted) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.bgPanel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gold, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 6))],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.auto_stories, size: 48, color: AppColors.accent),
                    const SizedBox(height: 8),
                    const Text(
                      'PLATAFORMA D&D',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isRegister ? 'Crea tu cuenta de aventurero' : 'Inicia sesión para continuar',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _userCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: _isRegister ? 'Nombre de usuario' : 'Usuario o correo',
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Campo obligatorio';
                        if (_isRegister && value.length < 3) return 'Mínimo 3 caracteres';
                        return null;
                      },
                    ),
                    if (_isRegister) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                            return 'Correo no válido';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _hidePass,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _busy ? null : _submit(),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_hidePass ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _hidePass = !_hidePass),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Campo obligatorio';
                        if (_isRegister && v.length < 8) return 'Mínimo 8 caracteres';
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8D7DA),
                          border: Border.all(color: const Color(0xFFF5C6CB)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(_error!, style: const TextStyle(color: Color(0xFF721C24))),
                      ),
                    ],
                    const SizedBox(height: 22),
                    ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_isRegister ? 'Crear cuenta' : 'Iniciar sesión'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _isRegister = !_isRegister;
                                _error = null;
                              }),
                      child: Text(_isRegister
                          ? '¿Ya tienes cuenta? Inicia sesión'
                          : '¿No tienes cuenta? Regístrate'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
