import 'package:dio/dio.dart';
import '../core/api_client.dart';

class AuthUser {
  final String id;
  final String email;
  final String? displayName;

  const AuthUser({required this.id, required this.email, this.displayName});

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] ?? '',
        email: json['email'] ?? '',
        displayName: json['displayName'],
      );
}

class AuthService {
  final ApiClient _apiClient;

  AuthService(this._apiClient);

  Future<ApiResponse<AuthUser>> register({
    required String email,
    required String password,
    String? displayName,
  }) =>
      _authenticate('/auth/register', {
        'email': email,
        'password': password,
        if (displayName != null && displayName.isNotEmpty) 'displayName': displayName,
      });

  Future<ApiResponse<AuthUser>> login({required String email, required String password}) =>
      _authenticate('/auth/login', {'email': email, 'password': password});

  /// Clears local tokens even if the server call fails — the user asked to sign
  /// out, and a network error must not leave them apparently signed in.
  Future<void> logout() async {
    final refreshToken = _apiClient.tokens.refreshToken;

    try {
      if (refreshToken != null) {
        await _apiClient.client.post('/auth/logout', data: {'refreshToken': refreshToken});
      }
    } on DioException {
      // Ignored on purpose — see above.
    } finally {
      await _apiClient.tokens.clear();
    }
  }

  /// Restores a session on app start. Returns null when there is no valid one.
  Future<AuthUser?> currentUser() async {
    await _apiClient.tokens.load();

    if (!_apiClient.tokens.isSignedIn) return null;

    try {
      final response = await _apiClient.client.get('/auth/me');
      return AuthUser.fromJson(response.data['data']);
    } on DioException {
      // The interceptor already tried to refresh; reaching here means it failed.
      return null;
    }
  }

  Future<ApiResponse<AuthUser>> _authenticate(String path, Map<String, dynamic> body) async {
    try {
      final response = await _apiClient.client.post(path, data: body);
      final data = response.data['data'] as Map<String, dynamic>;

      await _apiClient.tokens.save(
        accessToken: data['accessToken'],
        refreshToken: data['refreshToken'],
      );

      return ApiResponse(success: true, data: AuthUser.fromJson(data['user']));
    } on DioException catch (e) {
      return ApiResponse(success: false, error: friendlyError(e));
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }
}
