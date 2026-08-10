import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../providers/api_providers.dart';
import '../services/auth_service.dart';
import '../core/app_icons.dart';

/// Signed out: a prompt to sign in. Signed in: who you are, and a way out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          // A failure here means "couldn't confirm a session", so show signed-out.
          error: (_, _) => _SignedOut(),
          data: (user) => user == null ? _SignedOut() : _SignedIn(user: user),
        ),
      ),
    );
  }
}

class _SignedOut extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(RatrooTheme.space6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.user, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: RatrooTheme.space4),
            Text('You are not signed in', style: theme.textTheme.titleLarge),
            const SizedBox(height: RatrooTheme.space2),
            Text(
              'Sign in to save routes and keep them across devices.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: RatrooTheme.space6),
            FilledButton(
              onPressed: () => context.push('/auth'),
              child: const Text('Sign in or create account'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedIn extends ConsumerStatefulWidget {
  final AuthUser user;

  const _SignedIn({required this.user});

  @override
  ConsumerState<_SignedIn> createState() => _SignedInState();
}

class _SignedInState extends ConsumerState<_SignedIn> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    await ref.read(authServiceProvider).logout();

    if (!mounted) return;
    ref.invalidate(currentUserProvider);
    setState(() => _signingOut = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = widget.user;
    final initial = (user.displayName?.isNotEmpty ?? false)
        ? user.displayName![0].toUpperCase()
        : user.email.isNotEmpty
            ? user.email[0].toUpperCase()
            : '?';

    return ListView(
      padding: const EdgeInsets.all(RatrooTheme.space6),
      children: [
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            child: Text(
              initial,
              style: theme.textTheme.displaySmall?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
        ),
        const SizedBox(height: RatrooTheme.space4),
        Center(
          child: Text(user.displayName ?? user.email, style: theme.textTheme.headlineSmall),
        ),
        if (user.displayName != null) ...[
          const SizedBox(height: RatrooTheme.space1),
          Center(child: Text(user.email, style: theme.textTheme.bodyMedium)),
        ],
        const SizedBox(height: RatrooTheme.space8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(AppIcons.signOut, color: RatrooTheme.confidenceLowText),
                title: Text(
                  'Sign out',
                  style: theme.textTheme.titleSmall?.copyWith(color: RatrooTheme.confidenceLowText),
                ),
                trailing: _signingOut
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : null,
                onTap: _signingOut ? null : _signOut,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
