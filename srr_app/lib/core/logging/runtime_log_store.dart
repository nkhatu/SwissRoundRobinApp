// ---------------------------------------------------------------------------
// srr_app/lib/core/logging/runtime_log_store.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Centralized runtime log sink used during startup and error handling.
// Architecture:
// - Singleton log store for capturing messages and levels with optional trimming.
// Author: The Khatu Family Trust
// Copyright (c) The Khatu Family Trust
//
import 'dart:collection';

enum RuntimeLogLevel { info, warn, error }

class RuntimeLogEntry {
  RuntimeLogEntry(this.message, this.level, this.timestamp);

  final String message;
  final RuntimeLogLevel level;
  final DateTime timestamp;
}

class RuntimeLogStore {
  RuntimeLogStore._();

  static final RuntimeLogStore instance = RuntimeLogStore._();

  static const _maxEntries = 128;
  final _entries = Queue<RuntimeLogEntry>();

  void add(String message, {RuntimeLogLevel level = RuntimeLogLevel.info}) {
    final entry = RuntimeLogEntry(message, level, DateTime.now());
    if (_entries.length >= _maxEntries) {
      _entries.removeFirst();
    }
    _entries.add(entry);
    final prefix = level == RuntimeLogLevel.error
        ? 'ERROR'
        : level == RuntimeLogLevel.warn
        ? 'WARN'
        : 'LOG';
    // ignore: avoid_print
    print('[$prefix] $message');
  }

  List<RuntimeLogEntry> get entries => List.unmodifiable(_entries);
}
