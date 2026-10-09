import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';
import '../models/models.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  User? _currentUser;
  bool _isLoading = true;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;

  AuthProvider() {
    // Si el token vence, cerramos sesión automáticamente.
    ApiClient.onUnauthorized = () {
      if (_currentUser != null) logout();
    };
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token != null) {
      await fetchUser();
    } else {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUser() async {
    try {
      final data = await _api.get('/auth/me');
      _currentUser = User.fromJson(data);
    } catch (e) {
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Devuelve null si todo salió bien o el mensaje de error.
  /// [identifier] puede ser nombre de usuario o correo.
  Future<String?> login(String identifier, String password) async {
    try {
      final data = await _api.post('/auth/login', {
        'identifier': identifier.trim(),
        'password': password,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', data['access_token']);
      await fetchUser();
      return isAuthenticated ? null : 'No se pudo cargar tu perfil.';
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return 'Error inesperado: $e';
    }
  }

  Future<String?> register(String username, String email, String password) async {
    try {
      await _api.post('/auth/register', {
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
      });
      return await login(username, password);
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return 'Error inesperado: $e';
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    _currentUser = null;
    notifyListeners();
  }
}
