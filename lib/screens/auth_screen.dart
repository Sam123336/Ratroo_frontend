import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../providers/api_providers.dart';
import '../core/app_icons.dart';

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
                    _LabelledField(
                      label: 'Name',
                      optional: true,
                      child: TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(hintText: 'Sam Ghosh'),
                      ),
                    ),
                    const SizedBox(height: RatrooTheme.space4),
                  ],
                  _LabelledField(
                    label: 'Email',
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(hintText: 'you@example.com'),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return 'Enter your email.';
                        // Deliberately loose — the server is the real validator.
                        if (!email.contains('@') || !email.contains('.')) return 'Enter a valid email.';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: RatrooTheme.space4),
                  _LabelledField(
                    label: 'Password',
                    // Stated up front rather than only as an error after the
                    // fact — a rule you learn by failing is a rule shown too
                    // late. Sign-in has no such rule to state.
                    helper: _isRegistering ? 'At least 8 characters' : null,
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: [_isRegistering ? AutofillHints.newPassword : AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? AppIcons.hidePassword : AppIcons.showPassword),
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
                    const Icon(AppIcons.error, color: RatrooTheme.confidenceLowText, size: 20),
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

/// A form field with a label that stays put.
///
/// The three fields on this screen were placeholder-only. A hint disappears the
/// moment you type, so a filled form carried no labels at all — a rider who put
/// their email in the name box saw two identical-looking rows reading
/// "sam@gmail.com" and nothing to tell them apart. Screen readers had the same
/// problem: once a field has content there is nothing left to announce.
///
/// The label sits *above* the field rather than using `labelText`, because
/// these inputs are pill-shaped: a floating label notches the outline, and a
/// notch cut into a full-radius curve reads as a rendering fault.
///
/// [Semantics] carries the same name to assistive tech, since a sibling `Text`
/// is not programmatically tied to the field.
class _LabelledField extends StatelessWidget {
  final String label;
  final Widget child;

  /// Marks the field as not required, in words. An unmarked field is assumed
  /// required, so only the exception needs stating.
  final bool optional;

  /// A rule worth knowing before submitting rather than after failing.
  final String? helper;

  const _LabelledField({
    required this.label,
    required this.child,
    this.optional = false,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: RatrooTheme.space3, bottom: 6),
          child: Row(
            children: [
              Text(label, style: theme.textTheme.titleSmall),
              if (optional) ...[
                const SizedBox(width: RatrooTheme.space2),
                Text('Optional', style: theme.textTheme.labelSmall),
              ],
            ],
          ),
        ),
        Semantics(label: label, child: child),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(left: RatrooTheme.space3, top: 6),
            child: Text(helper!, style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }
}
