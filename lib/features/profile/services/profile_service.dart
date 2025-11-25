import 'package:transconnect/core/services/shared_preferences_service.dart';

class ProfileService {
  final SharedPreferencesService _prefsService = SharedPreferencesService();
  static const _statusKey = 'profile_status';
  static const _imagePathKey = 'profile_image_path';

  Future<void> saveProfile(String status, String? imagePath) async {
    await _prefsService.saveData(_statusKey, status);
    if (imagePath != null) {
      await _prefsService.saveData(_imagePathKey, imagePath);
    }
  }

  Future<String?> getStatus() async {
    return _prefsService.getData(_statusKey);
  }

  Future<String?> getImagePath() async {
    return _prefsService.getData(_imagePathKey);
  }
}
