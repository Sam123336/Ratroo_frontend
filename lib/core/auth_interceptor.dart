import 'dart:async';
import 'package:dio/dio.dart';
import 'token_store.dart';

/// Attaches the access token, and on a 401 refreshes once and replays the
/// request. Every other service stays unaware that auth exists.
class AuthInterceptor extends Interceptor {
  final TokenStore tokens;
  final Dio dio;

  /// Called when refresh fails — the session is unrecoverable and the UI should
  /// send the user back to sign-in.
  final void Function()? onSessionExpired;

  AuthInterceptor({required this.tokens, required this.dio, this.onSessionExpired});

  /// Shared across concurrent 401s. The home screen fires three requests at
  /// once; without this they would each refresh, and rotation would invalidate
  /// the others — logging the user out on every cold start.
  Future<bool>? _refreshInFlight;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    await tokens.load();
    final token = tokens.accessToken;

    if (token != null && !_isAuthEndpoint(options.path)) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra['retriedAfterRefresh'] == true;

    // Never refresh in response to the refresh call itself — that recurses.
    if (!isUnauthorized || alreadyRetried || _isAuthEndpoint(err.requestOptions.path)) {
      return handler.next(err);
    }

    if (tokens.refreshToken == null) {
      return handler.next(err);
    }

    final refreshed = await (_refreshInFlight ??= _refresh().whenComplete(() => _refreshInFlight = null));

    if (!refreshed) {
      return handler.next(err);
    }

    try {
      final options = err.requestOptions..extra['retriedAfterRefresh'] = true;
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      handler.resolve(await dio.fetch(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<bool> _refresh() async {
    try {
      // A bare Dio: the shared instance would run this interceptor again.
      final response = await Dio(BaseOptions(baseUrl: dio.options.baseUrl)).post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': tokens.refreshToken},
      );

      final data = response.data?['data'] as Map<String, dynamic>?;

      if (data == null) return false;

      await tokens.save(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      return true;
    } on DioException {
      // Refresh rejected: token expired, revoked, or replay-detected server-side.
      await tokens.clear();
      onSessionExpired?.call();
      return false;
    }
  }

  bool _isAuthEndpoint(String path) =>
      path.contains('/auth/refresh') || path.contains('/auth/login') || path.contains('/auth/register');
}
