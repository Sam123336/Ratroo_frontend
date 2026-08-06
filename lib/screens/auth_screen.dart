import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../providers/api_providers.dart';

/// One screen for both sign-in and sign-up — the fields are nearly identical,
/// and a toggle beats two near-duplicate screens.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isRegistering = false;
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final auth = ref.read(authServiceProvider);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final result = _isRegistering
        ? await auth.register(email: email, password: password, displayName: _nameController.text.trim())
        : await auth.login(email: email, password: password);

    if (!mounted) return;

    if (result.success) {
      // Tokens are already stored; re-resolve so the rest of the app sees the user.
      ref.invalidate(currentUserProvider);
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
      return;
    }

    setState(() {
      _submitting = false;
      _error = result.error ?? 'Something went wrong. Try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_isRegistering ? 'Create account' : 'Sign in')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(RatrooTheme.space6),
          children: [
            Text(
              _isRegistering ? 'Join Ratroo' : 'Welcome back',
              style: theme.textTheme.displaySmall,
            ),
            const SizedBox(height: RatrooTheme.space2),
            Text(
              _isRegistering
                  ? 'Save routes and sync them across your devices.'
                  : 'Sign in to see your saved routes.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: RatrooTheme.space8),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  if (_isRegistering) ...[
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(hintText: 'Your name (optional)'),
                    ),
                    const SizedBox(height: RatrooTheme.space4),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(hintText: 'Email'),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) return 'Enter your email.';
                      // Deliberately loose — the server is the real validator.
                      if (!email.contains('@') || !email.contains('.')) return 'Enter a valid email.';
                      return null;
                    },
                  ),
                  const SizedBox(height: RatrooTheme.space4),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    autofillHints: [_isRegistering ? AutofillHints.newPassword : AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                      ),
                    ),
                    validator: (value) {
                      if ((value ?? '').isEmpty) return 'Enter your password.';
                      // Only enforced on sign-up; an existing shorter password must still log in.
                      if (_isRegistering && value!.length < 8) return 'Use at least 8 characters.';
                      return null;
                    },
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: RatrooTheme.space4),
              Container(
                padding: const EdgeInsets.all(RatrooTheme.space3),
                decoration: BoxDecoration(
                  color: RatrooTheme.confidenceLowFill.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(RatrooTheme.radiusSm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: RatrooTheme.confidenceLowText, size: 20),
                    const SizedBox(width: RatrooTheme.space2),
                    Expanded(
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodyMedium?.copyWith(color: RatrooTheme.confidenceLowText),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: RatrooTheme.space6),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isRegistering ? 'Create account' : 'Sign in'),
            ),
            const SizedBox(height: RatrooTheme.space4),
            TextButton(
              onPressed: _submitting
                  ? null
                  : () => setState(() {
                        _isRegistering = !_isRegistering;
                        _error = null;
                      }),
              child: Text(
                _isRegistering ? 'Already have an account? Sign in' : "New here? Create an account",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
