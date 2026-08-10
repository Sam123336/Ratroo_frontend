import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ratroo_app/widgets/status_view.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  // The entrance animation owns a ticker; let it finish or the binding
  // complains about a pending timer at teardown.
  await tester.pumpAndSettle();
}

void main() {
  final options = RequestOptions(path: '/v1/stops/nearby');

  test('a dropped connection is offline, not a server fault', () {
    for (final type in [
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout,
    ]) {
      final view = StatusView.fromError(
        DioException(requestOptions: options, type: type),
        message: 'ignored',
      );
      expect(view.kind, StatusKind.offline, reason: '$type');
    }

    expect(
      StatusView.fromError(
        const SocketException('no route to host'),
        message: 'ignored',
      ).kind,
      StatusKind.offline,
    );
  });

  test('a server that answered badly is an error the rider cannot fix', () {
    final view = StatusView.fromError(
      DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: options, statusCode: 500),
      ),
      message: 'Could not load nearby stops.',
    );

    expect(view.kind, StatusKind.error);
    expect(view.message, 'Could not load nearby stops.');
  });

  testWidgets('exception text never reaches the rider', (tester) async {
    await _pump(
      tester,
      StatusView.fromError(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const SocketException('Connection refused (os error 61)'),
        ),
        message: 'Could not load nearby stops.',
        onRetry: () {},
      ),
    );

    expect(find.textContaining('DioException'), findsNothing);
    expect(find.textContaining('os error'), findsNothing);
    expect(find.text('No connection.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('an empty result keeps the specific reason it is empty', (tester) async {
    await _pump(
      tester,
      const StatusView(
        kind: StatusKind.empty,
        message: 'No bus stops within 30 km',
        detail: 'Only bus stops have been imported so far.',
      ),
    );

    expect(find.text('No bus stops within 30 km'), findsOneWidget);
    expect(find.text('Only bus stops have been imported so far.'), findsOneWidget);
    // Nothing to retry: the request worked.
    expect(find.text('Try again'), findsNothing);
  });
}
