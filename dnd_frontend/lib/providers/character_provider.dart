import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../models/models.dart';

class CharacterProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<Character> _myCharacters = [];
  bool _isLoading = false;
  String? lastError;

  List<Character> get myCharacters => _myCharacters;
  List<Character> get availableCharacters =>
      _myCharacters.where((c) => !c.inCampaign).toList();
  bool get isLoading => _isLoading;

  void clear() {
    _myCharacters = [];
    lastError = null;
    notifyListeners();
  }

  Future<void> fetchMyCharacters() async {
    _isLoading = true;
    notifyListeners();
    try {
      final List<dynamic> data = await _api.get('/characters/me');
      _myCharacters = data.map((e) => Character.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching characters: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Termina la campaña activa del personaje (se archiva en su historial).
  Future<bool> leaveCampaign(Character char) async {
    try {
      final data = await _api.patch('/characters/${char.id}', {
        'leave_campaign': true,
        'version': char.version,
      });
      _replace(Character.fromJson(data));
      lastError = null;
      return true;
    } on ApiException catch (e) {
      lastError = e.message;
      return false;
    }
  }

  Future<bool> deleteCharacter(Character char) async {
    try {
      await _api.delete('/characters/${char.id}');
      _myCharacters = _myCharacters.where((c) => c.id != char.id).toList();
      lastError = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      lastError = e.message;
      return false;
    }
  }

  void _replace(Character updated) {
    _myCharacters = [
      for (final c in _myCharacters) c.id == updated.id ? updated : c,
    ];
    notifyListeners();
  }
}
