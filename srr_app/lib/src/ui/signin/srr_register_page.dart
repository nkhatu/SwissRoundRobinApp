// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/srr_register_page.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Collects account registration inputs and creates new authenticated user sessions.
// Architecture:
// - Presentation-layer registration flow with validation and async state management.
// - Delegates identity creation and bootstrap behavior to shared auth/app services.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import 'package:catu_framework/catu_framework.dart';
import 'package:flutter/material.dart';

import '../helpers/srr_split_action_button.dart';

class SrrRegisterPage extends StatefulWidget {
  const SrrRegisterPage({super.key, required this.appState});

  final AppState appState;

  @override
  State<SrrRegisterPage> createState() => _SrrRegisterPageState();
}

class _SrrRegisterPageState extends State<SrrRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String _role = 'player';
  bool _busy = false;
  bool _hidePassword = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final displayName = '$firstName $lastName'.trim();

    setState(() => _busy = true);
    try {
      final ok = await widget.appState.register(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        displayName: displayName,
      );
      if (!ok) {
        if (!mounted) return;
        final message = widget.appState.signInError ?? 'Registration failed';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        return;
      }
      await widget.appState.bootstrap();
      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.bootstrap,
        (_) => false,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Create SRR Account',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) return 'Email is required.';
                      if (!RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(text)) {
                        return 'Enter a valid email address.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _firstNameCtrl,
                    decoration: const InputDecoration(labelText: 'First Name'),
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) return 'First name is required.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _lastNameCtrl,
                    decoration: const InputDecoration(labelText: 'Last Name'),
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) return 'Last name is required.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(value: 'player', child: Text('Player')),
                      DropdownMenuItem(
                        value: 'viewer',
                        child: Text('Viewer (read-only)'),
                      ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => _role = value);
                          },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _hidePassword,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _hidePassword = !_hidePassword),
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if ((value ?? '').length < 6) {
                        return 'Use at least 6 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmCtrl,
                    obscureText: _hideConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _hideConfirm = !_hideConfirm),
                        icon: Icon(
                          _hideConfirm
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                    onFieldSubmitted: (_) => _busy ? null : _submit(),
                    validator: (value) {
                      if (value != _passwordCtrl.text) {
                        return 'Passwords do not match.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  SrrSplitActionButton(
                    label: _busy ? 'Creating account...' : 'Create Account',
                    variant: SrrSplitActionButtonVariant.filled,
                    leadingIcon: Icons.person_add_alt_1_rounded,
                    onPressed: _busy ? null : _submit,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.pushNamedAndRemoveUntil(
                            context,
                            AppRoutes.signIn,
                            (_) => false,
                          ),
                    child: const Text('Back to sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
