// DO NOT CHANGE THIS FILE ANY CHANGE NEEDS A CORROSPONDING API CHANGE DONE BY PAIGE

abstract class ApiClientInterface {
  Future<dynamic> post({
    required String urlPath,
    required Map<String, String> jsonHeaders,
    required Map<String, dynamic> jsonPayload,
    int expectedStatusCode = 200,
  });

  Future<dynamic> put({
    required String urlPath,
    Map<String, String>? jsonHeaders,
    Map<String, dynamic>? jsonPayload,
    int expectedStatusCode = 200,
  });

  Future<dynamic> read({
    required String urlPath,
    Map<String, String>? jsonHeaders,
    int expectedStatusCode = 200,
  });

  Future<dynamic> update({
    required String urlPath,
    required Map<String, String> jsonHeaders,
    required Map<String, dynamic> jsonPayload,
    int expectedStatusCode = 200,
  });

  Future<dynamic> delete({
    required String urlPath,
    required Map<String, String> jsonHeaders,
    int expectedStatusCode = 204,
  });
}
