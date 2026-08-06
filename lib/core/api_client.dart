import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'auth_interceptor.dart';
import 'flavors.dart';
import 'token_store.dart';

class ApiMetadata {
  final double confidenceScore;
  final List<String> dataSources;
  final String timestamp;
  final int processingTimeMs;

  ApiMetadata({
    required this.confidenceScore,
    required this.dataSources,
    required this.timestamp,
    required this.processingTimeMs,
  });

  factory ApiMetadata.fromJson(Map<String, dynamic> json) {
    return ApiMetadata(
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0.0,
      dataSources: List<String>.from(json['dataSources'] ?? []),
      // Backend sends lastUpdated / lastSyncTimestamp.
      timestamp: json['timestamp'] ?? json['lastUpdated'] ?? json['lastSyncTimestamp'] ?? '',
      processingTimeMs: json['processingTimeMs'] ?? 0,
    );
  }
}

class ApiResponse<T> {
  final bool success;
  final T? data;
  final ApiMetadata? metadata;
  final String? error;

  ApiResponse({
    required this.success,
    this.data,
    this.metadata,
    this.error,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(dynamic json) fromJsonT) {
    return ApiResponse<T>(
      success: json['success'] ?? false,
      data: json['data'] != null ? fromJsonT(json['data']) : null,
      metadata: json['metadata'] != null ? ApiMetadata.fromJson(json['metadata']) : null,
      error: json['error'],
    );
  }
}

/// Dio's `.message` is a multi-paragraph essay about validateStatus — it was
/// rendering verbatim inside empty states. Map it to one human sentence, and
/// prefer the server's own message when there is one.
String friendlyError(DioException e) {
  final body = e.response?.data;

  if (body is Map) {
    // Our API puts it at the top level; Vercel's SSO block nests it under
    // `error`. Missing that made a "Protected deployment" 401 read as a wrong
    // password.
    final serverMessage = body['message'] ?? (body['error'] is Map ? body['error']['message'] : null);
    if (serverMessage is String && serverMessage.isNotEmpty) {
      // Name the culprit — this one is a deploy setting, not anything the user did.
      return body['protection'] != null
          ? 'This API is behind Vercel Deployment Protection. Disable it in the Vercel project settings.'
          : serverMessage;
    }
  }

  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'The server took too long to respond. Try again.';
    case DioExceptionType.connectionError:
      return "Can't reach Ratroo. Check your connection.";
    case DioExceptionType.badResponse:
      final code = e.response?.statusCode;
      if (code == 404) return 'Nothing found for this request.';
      if (code == 501) return 'This feature is not available yet.';
      return 'Something went wrong on our side ($code).';
    default:
      return 'Something went wrong. Try again.';
  }
}

/// Some endpoints return a bare list, others a paginated envelope
/// (`{data: [...], total, page}` for /routes, `{data: [...], count}` for
/// /stops/nearby). Unwrap both to a plain List.
List<dynamic> asList(dynamic data) {
  if (data is List) return data;
  if (data is Map && data['data'] is List) return data['data'] as List;
  return const [];
}

class ApiClient {
  late final Dio _dio;

  final TokenStore tokens;

  static String get baseUrl => AppFlavors.apiBaseUrl;

  ApiClient({TokenStore? tokenStore, void Function()? onSessionExpired})
      : tokens = tokenStore ?? TokenStore() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Accept': 'application/json',
      }
    ));

    // First in the chain: adds the bearer token and transparently refreshes on 401.
    _dio.interceptors.add(AuthInterceptor(
      tokens: tokens,
      dio: _dio,
      onSessionExpired: onSessionExpired,
    ));

    // Optional: Add logging interceptor for debug mode
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(responseBody: true, requestBody: true));
    }
  }

  Dio get client => _dio;
}
