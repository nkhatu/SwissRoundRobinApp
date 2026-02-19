// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/srr_page_scaffold.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Defines the common SRR page shell with header actions and footer framing.
// Architecture:
// - Shared layout scaffold used by feature pages for consistent app structure.
// - Separates cross-page chrome from feature-specific body implementations.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import 'package:catu_framework/catu_framework.dart';
import 'package:flutter/material.dart';

import '../config/srr_app_config.dart';
import 'srr_framework_menu.dart';

class SrrPageScaffold extends StatelessWidget {
  const SrrPageScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.appState,
    this.actions = const <Widget>[],
  });

  final String title;
  final Widget body;
  final AppState appState;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final appBarTitleStyle = Theme.of(context).appBarTheme.titleTextStyle;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: appBarTitleStyle?.copyWith(fontSize: 22),
        ),
        actions: [
          ...actions,
          AppMenuButton(
            onSelected: (action) => handleFrameworkMenuSelection(
              context: context,
              appState: appState,
              action: action,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: body),
          const Divider(height: 1),
          const AppPageFooter(text: SrrAppConfig.copyrightNotice),
        ],
      ),
    );
  }
}
