import 'package:flutter/foundation.dart';

class HomeAlertService extends ChangeNotifier {
  bool _dashboardAlerts = false;
  bool _meadowAlerts = false;

  bool get hasAlerts => _dashboardAlerts || _meadowAlerts;

  void setDashboardAlerts(bool value) {
    if (_dashboardAlerts == value) return;
    _dashboardAlerts = value;
    notifyListeners();
  }

  void setMeadowAlerts(bool value) {
    if (_meadowAlerts == value) return;
    _meadowAlerts = value;
    notifyListeners();
  }
}
