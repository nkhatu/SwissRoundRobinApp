// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/srr_sign_in_page.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Renders login UI and executes email, Google, and Apple sign-in actions.
// Architecture:
// - Presentation-layer screen managing form state, validation, and auth events.
// - Delegates provider auth and session bootstrap to injected auth/application services.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import 'package:catu_framework/catu_framework.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../helpers/srr_split_action_button.dart';

class SrrSignInPage extends StatefulWidget {
  const SrrSignInPage({super.key, required this.appState});

  final AppState appState;

  @override
  State<SrrSignInPage> createState() => _SrrSignInPageState();
}

class _SrrSignInPageState extends State<SrrSignInPage> {
  static const String _loginBackgroundAsset = 'assets/surco_bulldog.jpg';

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitEmailPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    final ok = await widget.appState.signIn(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.bootstrap,
        (_) => false,
      );
      return;
    }
    final message = widget.appState.signInError ?? 'Sign in failed';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submitGoogle() async {
    setState(() => _loading = true);
    final ok = await widget.appState.signInWithGoogle();
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.bootstrap,
        (_) => false,
      );
      return;
    }
    final message = widget.appState.signInError ?? 'Google sign in failed';
    if (_isCanceledSignIn(message)) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submitApple() async {
    setState(() => _loading = true);
    final ok = await widget.appState.signInWithApple();
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.bootstrap,
        (_) => false,
      );
      return;
    }
    final message = widget.appState.signInError ?? 'Apple sign in failed';
    if (_isCanceledSignIn(message)) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    final isValidEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!isValidEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email to reset password.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent to $email.')),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final detail = error.message?.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            detail == null || detail.isEmpty
                ? 'Unable to send password reset email.'
                : detail,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isCanceledSignIn(String? message) {
    final normalized = (message ?? '').toLowerCase();
    if (normalized.contains('canceled')) return true;
    if (normalized.contains('cancelled')) return true;
    if (normalized.contains('interrupted')) return true;
    return normalized.contains('authorizationerrorcode.canceled');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Sign In',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22),
        ),
        backgroundColor: const Color.fromRGBO(0, 0, 0, 0.35),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _loginBackgroundAsset,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return ColoredBox(color: theme.colorScheme.surface);
            },
          ),
          const ColoredBox(color: Color.fromRGBO(0, 0, 0, 0.55)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Card(
                    elevation: 8,
                    color: theme.colorScheme.surface.withAlpha(235),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                final value = (v ?? '').trim();
                                if (value.isEmpty) return 'Email is required';
                                if (!RegExp(
                                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                ).hasMatch(value)) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                ),
                              ),
                              validator: (v) {
                                final value = (v ?? '').trim();
                                if (value.isEmpty) {
                                  return 'Password is required';
                                }
                                return null;
                              },
                            ),
                            Align(
                              alignment: Alignment.center,
                              child: TextButton(
                                onPressed: _loading ? null : _sendPasswordReset,
                                child: const Text('Forgot password?'),
                              ),
                            ),
                            const PasswordRulesText(),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: SrrSplitActionButton(
                                label: _loading ? 'Signing in...' : 'Sign In',
                                variant: SrrSplitActionButtonVariant.filled,
                                leadingIcon: Icons.login_rounded,
                                onPressed: _loading
                                    ? null
                                    : _submitEmailPassword,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: SrrSplitActionButton(
                                label: 'Continue with Google',
                                variant: SrrSplitActionButtonVariant.outlined,
                                leadingIcon: Icons.g_mobiledata,
                                onPressed: _loading ? null : _submitGoogle,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: SrrSplitActionButton(
                                label: 'Continue with Apple',
                                variant: SrrSplitActionButtonVariant.outlined,
                                leadingIcon: Icons.apple,
                                onPressed: _loading ? null : _submitApple,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('No account?'),
                                TextButton(
                                  onPressed: _loading
                                      ? null
                                      : () => Navigator.pushNamed(
                                          context,
                                          AppRoutes.register,
                                        ),
                                  child: const Text('Register'),
                                ),
                              ],
                            ),
                            Text(
                              'Demo mode: use seeded credentials or create an account.',
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
