import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Error de la API con mensaje legible para el usuario.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  static String get baseUrl {
    // Si estamos en la web, usamos el mismo dominio que está sirviendo la página
    // Esto hace que funcione perfectamente con ngrok.
    if (const bool.fromEnvironment('dart.library.html')) {
      return '${Uri.base.origin}/api/v1';
    }
    // Para móvil/escritorio o pruebas locales
    return 'http://localhost:8000/api/v1';
  }

  /// Se invoca cuando el servidor responde 401 con sesión iniciada (token vencido).
  static void Function()? onUnauthorized;

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String endpoint) async {
    final response = await _send(() async => http.get(
          Uri.parse('$baseUrl$endpoint'),
          headers: await _getHeaders(),
        ));
    return _processResponse(response);
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final response = await _send(() async => http.post(
          Uri.parse('$baseUrl$endpoint'),
          headers: await _getHeaders(),
          body: jsonEncode(body),
        ));
    return _processResponse(response);
  }

  Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    final response = await _send(() async => http.patch(
          Uri.parse('$baseUrl$endpoint'),
          headers: await _getHeaders(),
          body: jsonEncode(body),
        ));
    return _processResponse(response);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(const Duration(seconds: 15));
    } on Exception {
      throw ApiException(0, 'No se pudo conectar con el servidor. ¿Está encendido el backend?');
    }
  }

  dynamic _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    if (response.statusCode == 401) {
      final prefs = SharedPreferences.getInstance();
      prefs.then((p) {
        if (p.getString('access_token') != null) onUnauthorized?.call();
      });
    }
    throw ApiException(response.statusCode, _extractMessage(response));
  }

  /// FastAPI devuelve {"detail": "texto"} o {"detail": [{"msg": ...}]} (422).
  String _extractMessage(http.Response response) {
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        final field = (first['loc'] is List && (first['loc'] as List).length > 1)
            ? '${(first['loc'] as List).last}: '
            : '';
        return '$field${first['msg']}';
      }
    } catch (_) {}
    return 'Error ${response.statusCode}';
  }
}
