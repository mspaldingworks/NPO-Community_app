import 'package:transconnect/core/services/shared_preferences_service.dart';
import 'package:http/http.dart' as http;
import 'package:transconnect/core/services/auth_service.dart';

class ProfileService {
  final SharedPreferencesService _prefsService = SharedPreferencesService();
  static const _statusKey = 'profile_status';
  static const _imagePathKey = 'profile_image_path';

  Future<void> saveProfile(
    String status,
    String? imagePath, {
    String? fullName,
    String? city,
    String? flair,
  }) async {
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
    // 1) If an image is provided, send a multipart PATCH with the image and status
    // 2) Otherwise, send a JSON PATCH for status only via AuthService
    // 3) Refresh the local user cache from the server
    final auth = AuthService();
    final token = await auth.getToken();
    if (token == null) {
      throw Exception('User not authenticated');
    }

    if (imagePath != null && imagePath.isNotEmpty) {
      final uri = Uri.parse('https://api.luxashome.com/api/profile/');
      final request = http.MultipartRequest('PATCH', uri)
        ..headers['Authorization'] = 'Token $token'
        ..fields['status_message'] = status;

      if (fullName != null) request.fields['full_name'] = fullName;
      if (city != null) request.fields['city'] = city;
      if (flair != null) request.fields['flair'] = flair;

      request.files.add(await http.MultipartFile.fromPath(
        'profile_pic',
        imagePath,
      ));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode != 200) {
        throw Exception('Failed to update profile: ${response.statusCode} ${response.body}');
      }
    } else {
      final Map<String, dynamic> updates = {'status_message': status};
      if (fullName != null) updates['full_name'] = fullName;
      if (city != null) updates['city'] = city;
      if (flair != null) updates['flair'] = flair;
      await auth.updateProfile(updates);
    }

    // Refresh the profile locally
    await auth.getProfile();

    // Optionally persist local hints for quick access/offline
    await _prefsService.saveData(_statusKey, status);
    if (imagePath != null && imagePath.isNotEmpty) {
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
