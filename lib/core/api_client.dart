import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'flavors.dart';

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
      timestamp: json['timestamp'] ?? '',
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

class ApiClient {
  late final Dio _dio;
  
  static String get baseUrl => AppFlavors.apiBaseUrl;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Accept': 'application/json',
      }
    ));

    // Optional: Add logging interceptor for debug mode
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(responseBody: true, requestBody: true));
    }
  }

  Dio get client => _dio;
}
