import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ratroo_app/core/auth_interceptor.dart';
import 'package:ratroo_app/core/token_store.dart';

/// In-memory stand-in — the real one needs platform channels.
class _FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read({required String key, dynamic iOptions, dynamic aOptions, dynamic lOptions,
      dynamic webOptions, dynamic mOptions, dynamic wOptions}) async => values[key];

  @override
  Future<void> write({required String key, required String? value, dynamic iOptions, dynamic aOptions,
      dynamic lOptions, dynamic webOptions, dynamic mOptions, dynamic wOptions}) async {
    if (value == null) { values.remove(key); } else { values[key] = value; }
  }

  @override
  Future<void> delete({required String key, dynamic iOptions, dynamic aOptions, dynamic lOptions,
      dynamic webOptions, dynamic mOptions, dynamic wOptions}) async => values.remove(key);

  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late HttpServer server;
  late int refreshCount;
  late List<String?> seenAuthHeaders;
  late String currentAccessToken;
  late bool refreshShouldFail;

  setUp(() async {
    refreshCount = 0;
    seenAuthHeaders = [];
    currentAccessToken = 'access-v2';
    refreshShouldFail = false;

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final auth = request.headers.value('authorization');

      if (request.uri.path == '/auth/refresh') {
        refreshCount++;
        request.response
          ..statusCode = refreshShouldFail ? 401 : 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(refreshShouldFail
              ? {'message': 'Refresh token has already been used.'}
              : {
                  'data': {'accessToken': currentAccessToken, 'refreshToken': 'refresh-v2'}
                }));
        await request.response.close();
        return;
      }

      seenAuthHeaders.add(auth);

      // Anything other than the refreshed token is rejected.
      final ok = auth == 'Bearer $currentAccessToken';
      request.response
        ..statusCode = ok ? 200 : 401
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(ok ? {'data': 'ok'} : {'error': 'expired'}));
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  Future<(Dio, TokenStore, List<int>)> buildClient() async {
    final storage = _FakeSecureStorage();
    final tokens = TokenStore(storage);
    await tokens.save(accessToken: 'access-v1-expired', refreshToken: 'refresh-v1');

    final expiredEvents = <int>[];
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:${server.port}'));
    dio.interceptors.add(AuthInterceptor(
      tokens: tokens,
      dio: dio,
      onSessionExpired: () => expiredEvents.add(1),
    ));
    return (dio, tokens, expiredEvents);
  }

  test('attaches bearer token and retries once after refreshing on 401', () async {
    final (dio, tokens, _) = await buildClient();

    final response = await dio.get('/v1/favorites');

    expect(response.statusCode, 200);
    expect(refreshCount, 1);
    // First attempt with the stale token, replay with the fresh one.
    expect(seenAuthHeaders, ['Bearer access-v1-expired', 'Bearer access-v2']);
    expect(tokens.accessToken, 'access-v2');
    expect(tokens.refreshToken, 'refresh-v2');
  });

  test('concurrent 401s share one refresh', () async {
    final (dio, _, _) = await buildClient();

    // The home screen fires three at once. Refreshing three times would rotate
    // the token out from under the other two and sign the user out.
    final responses = await Future.wait([
      dio.get('/v1/favorites'),
      dio.get('/v1/analytics'),
      dio.get('/v1/stops/nearby'),
    ]);

    expect(responses.every((r) => r.statusCode == 200), isTrue);
    expect(refreshCount, 1);
  });

  test('rejected refresh clears tokens and reports the session as expired', () async {
    final (dio, tokens, expiredEvents) = await buildClient();
    // Mirrors the server's replay detection revoking the whole session.
    refreshShouldFail = true;

    await expectLater(dio.get('/v1/favorites'), throwsA(isA<DioException>()));

    expect(refreshCount, 1, reason: 'must not retry the refresh in a loop');
    expect(tokens.accessToken, isNull);
    expect(tokens.refreshToken, isNull);
    expect(expiredEvents, hasLength(1));
  });
}
