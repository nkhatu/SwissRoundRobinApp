// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/srr_complete_profile_page.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Forces profile completion after auth and persists role-aware registration details.
// Architecture:
// - Presentation flow with form validation and role-specific behavior rules.
// - Delegates profile persistence and re-bootstrap to API client and app state.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import 'package:catu_framework/catu_framework.dart';
import 'package:flutter/material.dart';

import '../../api/api_exceptions.dart';
import '../../auth/srr_auth_service.dart';
import '../../models/srr_models.dart';
import '../helpers/srr_split_action_button.dart';

class SrrCompleteProfilePage extends StatefulWidget {
  const SrrCompleteProfilePage({
    super.key,
    required this.appState,
    required this.authService,
  });

  final AppState appState;
  final SrrAuthService authService;

  @override
  State<SrrCompleteProfilePage> createState() => _SrrCompleteProfilePageState();
}

class _SrrCompleteProfilePageState extends State<SrrCompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  bool _loading = false;
  String _role = 'player';

  @override
  void initState() {
    super.initState();
    _seedFromCurrentUser(widget.authService.currentAccount);
  }

  void _seedFromCurrentUser(SrrUser? user) {
    if (user == null) return;
    final first = user.firstName?.trim() ?? '';
    final last = user.lastName?.trim() ?? '';
    if (first.isNotEmpty) {
      _firstNameCtrl.text = first;
    } else if (user.displayName.trim().isNotEmpty) {
      final parts = user.displayName.trim().split(RegExp(r'\s+'));
      _firstNameCtrl.text = parts.first;
      if (parts.length > 1) {
        _lastNameCtrl.text = parts.sublist(1).join(' ');
      }
    }
    if (last.isNotEmpty) {
      _lastNameCtrl.text = last;
    }
    if (user.role == 'player' || user.role == 'viewer') {
      _role = user.role;
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = widget.authService.currentAccount;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session is missing. Sign in again.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final roleToPersist = user.isAdmin ? user.role : _role;
      await widget.authService.upsertProfile(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        role: roleToPersist,
      );
      await widget.appState.bootstrap();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.bootstrap,
        (_) => false,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.currentAccount;
    final isAdmin = user?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Complete Registration',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Create or update your profile before continuing.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _firstNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'First name',
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'First name is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _lastNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Last name',
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Last name is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _role,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: const [
                          DropdownMenuItem(
                            value: 'player',
                            child: Text('Player'),
                          ),
                          DropdownMenuItem(
                            value: 'viewer',
                            child: Text('Viewer'),
                          ),
                        ],
                        onChanged: isAdmin || _loading
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() => _role = value);
                              },
                      ),
                      if (isAdmin) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Admin role is fixed and cannot be changed here.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 16),
                      SrrSplitActionButton(
                        label: _loading ? 'Saving...' : 'Continue',
                        variant: SrrSplitActionButtonVariant.filled,
                        leadingIcon: Icons.check_circle_outline,
                        onPressed: _loading ? null : _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
