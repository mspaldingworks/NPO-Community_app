import 'package:flutter/foundation.dart';
import 'package:npo_community/core/services/givebutter_service.dart';
import 'package:npo_community/features/fundraising/models/givebutter_campaign.dart';

enum FundraisingStatus { idle, loading, loaded, error }

class FundraisingController extends ChangeNotifier {
  FundraisingController(this._service);

  final GivebutterService _service;

  List<GivebutterCampaign> _campaigns = [];
  FundraisingStatus _status = FundraisingStatus.idle;
  String? _error;
  bool _creating = false;

  List<GivebutterCampaign> get campaigns => List.unmodifiable(_campaigns);
  FundraisingStatus get status => _status;
  String? get error => _error;
  bool get isCreating => _creating;
  bool get isConfigured => _service.isConfigured;

  Future<void> loadCampaigns() async {
    if (_status == FundraisingStatus.loading) return;

    if (!_service.isConfigured) {
      _status = FundraisingStatus.error;
      _error =
          'Givebutter API key not configured.\nAdd --dart-define=GIVEBUTTER_API_KEY=<key> to your build.';
      notifyListeners();
      return;
    }

    _status = FundraisingStatus.loading;
    _error = null;
    notifyListeners();

    try {
      _campaigns = await _service.listCampaigns();
      _status = FundraisingStatus.loaded;
    } catch (e) {
      _status = FundraisingStatus.error;
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  Future<GivebutterCampaign> createCampaign({
    required String title,
    String? subtitle,
    String? description,
    int? goal,
    String type = 'fundraiser',
    String? endAt,
  }) async {
    _creating = true;
    notifyListeners();
    try {
      final campaign = await _service.createCampaign(
        title: title,
        subtitle: subtitle,
        description: description,
        goal: goal,
        type: type,
        endAt: endAt,
      );
      _campaigns = [campaign, ..._campaigns];
      _status = FundraisingStatus.loaded;
      _creating = false;
      notifyListeners();
      return campaign;
    } catch (e) {
      _creating = false;
      notifyListeners();
      rethrow;
    }
  }
}
