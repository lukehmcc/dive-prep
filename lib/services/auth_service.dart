import 'package:dio/dio.dart';
import 'package:dive_prep/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final Dio _dio = Dio();

  // Login and return Map with token/userId or throw error
  Future<Map<String, String>> login(
    String url,
    String username,
    String password,
  ) async {
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);

    try {
      final response = await _dio.post(
        '$url/Users/AuthenticateByName',
        data: {'Username': username, 'Pw': password},
        options: Options(
          headers: {
            'X-Emby-Authorization':
                'MediaBrowser Client="FlutterDownloader", Device="FlutterApp", DeviceId="12345", Version="1.0.0"',
          },
        ),
      );
      logger.d(response);

      final token = response.data['AccessToken'];
      final userId = response.data['SessionInfo']['UserId'];

      await _saveSession(url, token, userId);
      return {'url': url, 'token': token, 'userId': userId};
    } catch (e) {
      logger.e("Login failed: $e");
      throw Exception("Login Failed: $e");
    }
  }

  Future<void> _saveSession(String url, String token, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
    await prefs.setString('server_url', url);
    await prefs.setString('user_id', userId);
  }

  Future<Map<String, String>?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final url = prefs.getString('server_url');
    final uid = prefs.getString('user_id');

    if (token != null && url != null && uid != null) {
      return {'url': url, 'token': token, 'userId': uid};
    }
    return null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Dio getClient(String url, String token) {
    final dio = Dio(BaseOptions(baseUrl: url));
    dio.options.headers['X-MediaBrowser-Token'] = token;
    return dio;
  }
}
