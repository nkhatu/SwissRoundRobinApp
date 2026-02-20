// ---------------------------------------------------------------------------
// srr_app/lib/src/api/api_exceptions.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Centralizes API-level exception type for reuse across clients and UI.
// Architecture:
// - Simple immutable exception that preserves HTTP status when available.
// Author: The Khatu Family Trust
// Copyright (c) The Khatu Family Trust
//
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
