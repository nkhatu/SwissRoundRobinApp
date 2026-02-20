// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/srr_copyright_page.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Hosts the Copyright page backed by bundled markdown content.
// Architecture:
// - Thin page wrapper that configures copyright document title and source asset.
// - Delegates document rendering to the shared markdown document component.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import 'package:catu_framework/catu_framework.dart';
import 'package:flutter/material.dart';

import '../helpers/srr_markdown_document_page.dart';

class SrrCopyrightPage extends StatelessWidget {
  const SrrCopyrightPage({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return SrrMarkdownDocumentPage(
      appState: appState,
      title: 'Copyright',
      assetPath: 'assets/content/copyright.md',
    );
  }
}
