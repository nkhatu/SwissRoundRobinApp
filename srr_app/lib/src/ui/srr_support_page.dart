// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/srr_support_page.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Hosts the Support page backed by bundled markdown content.
// Architecture:
// - Thin page wrapper that configures support document title and source asset.
// - Delegates document rendering to the shared markdown document component.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import 'package:catu_framework/catu_framework.dart';
import 'package:flutter/material.dart';

import '../config/srr_app_config.dart';
import 'srr_markdown_document_page.dart';

class SrrSupportPage extends StatelessWidget {
  const SrrSupportPage({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return SrrMarkdownDocumentPage(
      appState: appState,
      title: 'Support',
      assetPath: 'assets/content/support.md',
      intro: 'For help, contact ${SrrAppConfig.supportEmail}.',
    );
  }
}
