// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/app_bootstrap.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Wraps the SrrTournamentApp shell and exposes dependencies to the widget tree.
// Architecture:
// - Keeps the top-level MaterialApp configuration behind a dedicated widget.
// Author: The Khatu Family Trust
// Copyright (c) The Khatu Family Trust
//
import 'package:flutter/widgets.dart';

import '../di/srr_dependencies.dart';
import 'tournament/srr_tournament_app.dart';

class AppBootstrap extends StatelessWidget {
  const AppBootstrap({super.key, required this.dependencies});

  final SrrDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return SrrTournamentApp(dependencies: dependencies);
  }
}
