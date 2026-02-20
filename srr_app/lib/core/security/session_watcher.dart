// ---------------------------------------------------------------------------
// srr_app/lib/core/security/session_watcher.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Watches `AppState` changes and rebuilds the widget tree when sessions evolve.
// Architecture:
// - Minimal StatefulWidget that keeps a listener on `AppState`.
// Author: The Khatu Family Trust
// Copyright (c) The Khatu Family Trust
//
import 'package:catu_framework/catu_framework.dart';
import 'package:flutter/material.dart';

class SessionWatcher extends StatefulWidget {
  const SessionWatcher({
    super.key,
    required this.appState,
    required this.child,
  });

  final AppState appState;
  final Widget child;

  @override
  State<SessionWatcher> createState() => _SessionWatcherState();
}

class _SessionWatcherState extends State<SessionWatcher> {
  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onAppStateChanged);
  }

  @override
  void didUpdateWidget(covariant SessionWatcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appState != widget.appState) {
      oldWidget.appState.removeListener(_onAppStateChanged);
      widget.appState.addListener(_onAppStateChanged);
    }
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
