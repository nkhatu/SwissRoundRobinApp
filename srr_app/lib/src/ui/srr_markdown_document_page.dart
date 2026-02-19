// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/srr_markdown_document_page.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Loads markdown assets and renders legal/support document content pages.
// Architecture:
// - Feature component for document loading, error handling, and markdown rendering.
// - Decouples document presentation from individual legal/support page wrappers.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import 'package:catu_framework/catu_framework.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'srr_page_scaffold.dart';

class SrrMarkdownDocumentPage extends StatefulWidget {
  const SrrMarkdownDocumentPage({
    super.key,
    required this.appState,
    required this.title,
    required this.assetPath,
    this.intro,
  });

  final AppState appState;
  final String title;
  final String assetPath;
  final String? intro;

  @override
  State<SrrMarkdownDocumentPage> createState() =>
      _SrrMarkdownDocumentPageState();
}

class _SrrMarkdownDocumentPageState extends State<SrrMarkdownDocumentPage> {
  String? _markdown;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _markdown = null;
      _error = null;
    });
    try {
      final content = await rootBundle.loadString(widget.assetPath);
      if (!mounted) return;
      setState(() => _markdown = content);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SrrPageScaffold(
      title: widget.title,
      appState: widget.appState,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.intro != null && widget.intro!.trim().isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(widget.intro!, textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildBody(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Unable to load document.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      );
    }
    if (_markdown == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return MarkdownBody(
      data: _markdown!,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
    );
  }
}
