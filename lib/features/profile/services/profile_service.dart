import 'package:transconnect/core/services/shared_preferences_service.dart';

class ProfileService {
  final SharedPreferencesService _prefsService = SharedPreferencesService();
  static const _statusKey = 'profile_status';
  static const _imagePathKey = 'profile_image_path';

  Future<void> saveProfile(String status, String? imagePath) async {
    // TODO MADDIE Expand this to use the update form to post a new photo. 
    /*
    ### Update User Profile with Image
      PATCH https://api.luxashome.com/api/profile/
      Content-Type: multipart/form-data; boundary=MfnBoundry
      Authorization: Token 79abeae18b216cb54c04b5032ca373d4ef509434

      --MfnBoundry
      Content-Disposition: form-data; name="profile_pic"; filename="LuxToken.png"
      Content-Type: image/png

      < /mnt/c/Users/bmaxw/Project/06-Freelance/TransConnectKy/transapp/LuxToken.png

      --MfnBoundry
    */
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
