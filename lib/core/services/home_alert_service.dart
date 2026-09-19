import 'package:flutter/foundation.dart';

class HomeAlertService extends ChangeNotifier {
  bool _dashboardAlerts = false;

  bool get hasAlerts => _dashboardAlerts;

  void setDashboardAlerts(bool value) {
    if (_dashboardAlerts == value) return;
    _dashboardAlerts = value;
    notifyListeners();
  }
}
