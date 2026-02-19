// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/srr_framework_menu.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Maps framework menu events to SRR route transitions and app actions.
// Architecture:
// - Navigation adapter layer between shared framework actions and app-specific routes.
// - Centralizes menu behavior so pages stay focused on feature content.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import 'package:catu_framework/catu_framework.dart';
import 'package:flutter/material.dart';

Future<void> handleFrameworkMenuSelection({
  required BuildContext context,
  required AppState appState,
  required AppMenuAction action,
}) async {
  switch (action) {
    case AppMenuAction.userProfile:
      Navigator.pushNamed(context, AppRoutes.profile);
      break;
    case AppMenuAction.inbox:
      Navigator.pushNamed(context, AppRoutes.inbox);
      break;
    case AppMenuAction.support:
      Navigator.pushNamed(context, AppRoutes.support);
      break;
    case AppMenuAction.privacy:
      Navigator.pushNamed(context, AppRoutes.privacy);
      break;
    case AppMenuAction.copyrightAndLicense:
      Navigator.pushNamed(context, AppRoutes.copyright);
      break;
    case AppMenuAction.feedback:
      Navigator.pushNamed(context, AppRoutes.feedback);
      break;
    case AppMenuAction.settings:
      Navigator.pushNamed(context, AppRoutes.settings);
      break;
    case AppMenuAction.logout:
      await appState.signOut();
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.signIn,
        (_) => false,
      );
      break;
  }
}
