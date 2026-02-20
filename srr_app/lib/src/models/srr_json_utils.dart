// ---------------------------------------------------------------------------
// srr_app/lib/src/models/srr_json_utils.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Utility helpers for decoding JSON responses.
// Architecture:
// - Provides centralized decode helpers consumed by the API layer.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import 'dart:convert';

Map<String, dynamic> decodeObject(String jsonBody) =>
    json.decode(jsonBody) as Map<String, dynamic>;

List<Map<String, dynamic>> decodeObjectList(String jsonBody) =>
    (json.decode(jsonBody) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .toList(growable: false);
