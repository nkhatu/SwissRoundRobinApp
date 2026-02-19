// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/srr_feedback_page.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Collects user feedback details and launches optional support email draft flow.
// Architecture:
// - Presentation-layer form with validation, category selection, and submission state.
// - Delegates analytics and mailto launch side effects to framework/service integrations.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import 'package:catu_framework/catu_framework.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/srr_api_client.dart';
import '../config/srr_app_config.dart';
import 'srr_page_scaffold.dart';
import 'srr_split_action_button.dart';

class SrrFeedbackPage extends StatefulWidget {
  const SrrFeedbackPage({
    super.key,
    required this.appState,
    required this.apiClient,
    required this.analytics,
  });

  final AppState appState;
  final SrrApiClient apiClient;
  final CrashAnalyticsService analytics;

  @override
  State<SrrFeedbackPage> createState() => _SrrFeedbackPageState();
}

class _SrrFeedbackPageState extends State<SrrFeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();

  bool _submitting = false;
  bool _sendAsEmail = true;
  String _category = 'Suggestion';

  static const Map<String, String> _categoryEmailMap = <String, String>{
    'Suggestion': SrrAppConfig.supportEmail,
    'Bug Report': SrrAppConfig.supportEmail,
    'Support': SrrAppConfig.supportEmail,
  };

  String get _recipientEmail =>
      _categoryEmailMap[_category] ?? SrrAppConfig.supportEmail;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.apiClient.currentUserSnapshot;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SrrPageScaffold(
      title: 'Send Feedback',
      appState: widget.appState,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'We read every submission. Share suggestions, bug reports, or support requests.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: user?.email ?? '',
                readOnly: true,
                decoration: const InputDecoration(labelText: 'From'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: ValueKey('feedback-to-$_category'),
                initialValue: _recipientEmail,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'To'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
                  DropdownMenuItem(
                    value: 'Suggestion',
                    child: Text('Suggestion'),
                  ),
                  DropdownMenuItem(
                    value: 'Bug Report',
                    child: Text('Bug Report'),
                  ),
                  DropdownMenuItem(value: 'Support', child: Text('Support')),
                ],
                onChanged: _submitting
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _category = value);
                      },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _messageController,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'Please enter your feedback.';
                  }
                  if (text.length < 10) {
                    return 'Please add a bit more detail.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _sendAsEmail,
                title: const Text('Send as email'),
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _sendAsEmail = value ?? false),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 280,
                child: SrrSplitActionButton(
                  label: _submitting
                      ? 'Submitting...'
                      : (_sendAsEmail ? 'Send Email' : 'Submit Feedback'),
                  variant: SrrSplitActionButtonVariant.filled,
                  leadingIcon: Icons.send,
                  onPressed: _submitting ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    final message = _messageController.text.trim();
    try {
      widget.analytics.logEvent('feedback_submitted');
      if (_sendAsEmail) {
        final opened = await _openEmailDraft(message);
        if (!mounted) return;
        _showSnack(
          opened
              ? 'Feedback prepared in your email app.'
              : 'Feedback captured, but email app could not be opened.',
        );
      } else {
        if (!mounted) return;
        _showSnack('Thanks for your feedback.');
      }
      _messageController.clear();
    } catch (_) {
      if (!mounted) return;
      _showSnack('Unable to submit feedback.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<bool> _openEmailDraft(String message) async {
    final subject = '[Carrom SRR] $_category';
    final uri = Uri.parse(
      'mailto:$_recipientEmail'
      '?subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(message)}',
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
