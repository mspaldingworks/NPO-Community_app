import 'package:scoped_model/scoped_model.dart';

class TemplateStateModel extends Model {
  int _demoCounter = 0;

  int get demoCounter => _demoCounter;

  void incrementCounter() {
    _demoCounter += 1;
    notifyListeners();
  }
}
