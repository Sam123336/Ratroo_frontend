import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/app_icons.dart';
import '../core/theme.dart';

/// What kind of nothing the rider is looking at.
///
/// These are not interchangeable. "We could not reach the server" and "this
/// stop has no timetable" look identical if you draw them the same way, but
/// one is worth retrying and the other never will be. Screens used to pick a
/// glyph per call site and drifted: three icon sizes, `Colors.redAccent` and
/// `Colors.grey` outside the theme, and five near-identical private widgets.
enum StatusKind {
  /// The request failed on the way out — no network, DNS, timeout.
  offline,

  /// We reached the server and it failed.
  error,

  /// The request worked. There is genuinely nothing here.
  empty,

  /// The rider's query matched nothing.
  noResults,

  /// We do not know where the rider is, or they arrived without a target.
  noLocation,

  /// No journey connects the two ends.
  noRoute,
}

/// The full-screen state a rider sees when there is no content.
///
/// Deliberately never renders the raw exception. A rider reading
/// `DioException [connection error]` learns nothing they can act on; the
/// message says what happened and the action says what to do about it.
/// The underlying error still goes to the console via [debugDetail].
class StatusView extends StatelessWidget {
  final StatusKind kind;
  final String message;

  /// Optional second line: the specific, rider-useful detail. "WBTC does not
  /// publish times for this route" belongs here. Exception text does not.
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  const StatusView({
    super.key,
    required this.kind,
    required this.message,
    this.detail,
    this.actionLabel,
    this.onAction,
  });

  /// Builds the right state from a thrown error, so every screen classifies
  /// a dropped connection the same way instead of calling it all "offline".
  factory StatusView.fromError(
    Object error, {
    required String message,
    VoidCallback? onRetry,
  }) {
    debugPrint('StatusView: $error');
    return StatusView(
      kind: _isOffline(error) ? StatusKind.offline : StatusKind.error,
      message: _isOffline(error)
          ? 'No connection.'
          : message,
      detail: _isOffline(error)
          ? 'Check your network and try again.'
          : 'Something went wrong at our end.',
      actionLabel: onRetry == null ? null : 'Try again',
      onAction: onRetry,
    );
  }

  static bool _isOffline(Object error) {
    if (error is SocketException) return true;
    if (error is DioException) {
      return error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.error is SocketException;
    }
    return false;
  }

  IconData get _icon => switch (kind) {
        StatusKind.offline => AppIcons.offline,
        StatusKind.error => AppIcons.error,
        StatusKind.empty => AppIcons.time,
        StatusKind.noResults => AppIcons.noResults,
        StatusKind.noLocation => AppIcons.locationOff,
        StatusKind.noRoute => AppIcons.noRoute,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFault = kind == StatusKind.offline || kind == StatusKind.error;
    final tint = isFault ? RatrooTheme.confidenceLowText : theme.colorScheme.primary;

    return Center(
      child: SingleChildScrollView(
        // Scrollable so a RefreshIndicator above it still has something to pull,
        // and so the state survives a landscape phone.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(RatrooTheme.space8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, size: 38, color: tint),
            )
                .animate()
                .scale(
                  duration: 320.ms,
                  curve: Curves.easeOutBack,
                  begin: const Offset(0.85, 0.85),
                )
                .fadeIn(duration: 220.ms),
            const SizedBox(height: RatrooTheme.space6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (detail != null) ...[
              const SizedBox(height: RatrooTheme.space2),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (onAction != null) ...[
              const SizedBox(height: RatrooTheme.space6),
              FilledButton.tonalIcon(
                onPressed: onAction,
                icon: const Icon(AppIcons.refresh, size: 18),
                label: Text(actionLabel ?? 'Try again'),
              ),
            ],
          ],
        )
            .animate()
            .fadeIn(duration: 260.ms)
            .moveY(begin: 8, end: 0, curve: Curves.easeOut),
      ),
    );
  }
}
