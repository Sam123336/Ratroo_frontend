import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_icons.dart';
import '../core/theme.dart';
import '../services/service_request_service.dart';

/// What a rider sees when Ratroo holds nothing for where they are.
///
/// They opened a transit app in Bihar and found an empty screen. Saying so
/// plainly, and offering to tell them when we arrive, is the only honest thing
/// on offer — and their number is the signal that decides which state we
/// ingest next.
///
/// Not a paywall or a sign-up: no account, one field, and it says what will
/// happen with the number.
class NotServicedYet extends ConsumerStatefulWidget {
  final String stateCode;

  /// "Bihar" — what a rider calls it, not the code.
  final String? regionName;

  final double? latitude;
  final double? longitude;

  const NotServicedYet({
    super.key,
    required this.stateCode,
    this.regionName,
    this.latitude,
    this.longitude,
  });

  @override
  ConsumerState<NotServicedYet> createState() => _NotServicedYetState();
}

class _NotServicedYetState extends ConsumerState<NotServicedYet> {
  final _phone = TextEditingController();
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phone.text.trim();
    // Checked here as well as on the server so the rider is told immediately,
    // rather than after a round trip.
    if (!RegExp(r'^(\+?91[\s-]?)?[6-9]\d{9}$').hasMatch(phone)) {
      setState(() => _error = 'Enter a 10-digit mobile number.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    final result = await ref
        .read(serviceRequestServiceProvider)
        .request(
          stateCode: widget.stateCode,
          phone: phone,
          regionName: widget.regionName,
          latitude: widget.latitude,
          longitude: widget.longitude,
        );

    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = result.success;
      _error = result.success ? null : result.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final place = widget.regionName ?? 'your area';

    return Container(
      padding: const EdgeInsets.all(RatrooTheme.space6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(RatrooTheme.radiusXl),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.place, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: RatrooTheme.space2),
              Expanded(
                child: Text(
                  'Ratroo is not in $place yet',
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: RatrooTheme.space2),
          Text(
            // Names where we are, so it reads as a young product rather than a
            // broken one.
            'We cover West Bengal today, and part of Karnataka. Leave your '
            'number and we will tell you the day $place goes live.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: RatrooTheme.space6),
          if (_sent)
            Row(
              children: [
                const Icon(
                  AppIcons.verified,
                  size: 18,
                  color: RatrooTheme.confidenceHighText,
                ),
                const SizedBox(width: RatrooTheme.space2),
                Expanded(
                  child: Text(
                    'Thank you — we will text you when $place is live.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: RatrooTheme.confidenceHighText,
                    ),
                  ),
                ),
              ],
            )
          else ...[
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              // Digits, spaces and a leading + only: the number pad on Android
              // otherwise offers characters the field can never accept.
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
                LengthLimitingTextInputFormatter(16),
              ],
              enabled: !_sending,
              decoration: InputDecoration(
                labelText: 'Mobile number',
                hintText: '98300 12345',
                errorText: _error,
                prefixIcon: const Icon(AppIcons.user, size: 18),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: RatrooTheme.space4),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _sending ? null : _submit,
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Tell me when it launches'),
              ),
            ),
            const SizedBox(height: RatrooTheme.space2),
            Text(
              'Used only to tell you when $place is live. Nothing else.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
