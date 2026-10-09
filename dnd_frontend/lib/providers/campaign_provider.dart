import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../models/models.dart';

class CampaignProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<Campaign> _campaigns = [];
  bool _isLoading = false;
  String? lastError;

  List<Campaign> get campaigns => _campaigns;
  bool get isLoading => _isLoading;

  void clear() {
    _campaigns = [];
    lastError = null;
    notifyListeners();
  }

  Future<void> fetchMyCampaigns() async {
    _isLoading = true;
    notifyListeners();
    try {
      final List<dynamic> data = await _api.get('/campaigns/');
      _campaigns = data.map((e) => Campaign.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching campaigns: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Campaign?> createCampaign(String name, String description) async {
    try {
      final data = await _api.post('/campaigns/', {
        'name': name,
        'description': description,
      });
      final newCampaign = Campaign.fromJson(data);
      _campaigns = [newCampaign, ..._campaigns];
      lastError = null;
      notifyListeners();
      return newCampaign;
    } on ApiException catch (e) {
      lastError = e.message;
      return null;
    }
  }

  /// Une al jugador a una campaña con uno de sus personajes (lo valida el backend).
  Future<Campaign?> joinCampaign(String joinCode, String characterId) async {
    try {
      final data = await _api.post('/campaigns/join', {
        'join_code': joinCode,
        'character_id': characterId,
      });
      final joined = Campaign.fromJson(data);
      if (!_campaigns.any((c) => c.id == joined.id)) {
        _campaigns = [joined, ..._campaigns];
      }
      lastError = null;
      notifyListeners();
      return joined;
    } on ApiException catch (e) {
      lastError = e.message;
      return null;
    }
  }

  Future<bool> updateCampaignNotes(String campaignId, String notes) async {
    try {
      final data = await _api.patch('/campaigns/$campaignId', {'dm_notes': notes});
      final updated = Campaign.fromJson(data);
      _campaigns = [
        for (final c in _campaigns) c.id == campaignId ? updated : c,
      ];
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      lastError = e.message;
      return false;
    }
  }
}
