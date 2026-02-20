// ---------------------------------------------------------------------------
// srr_app/lib/src/api/srr_api_transport.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Provides shared HTTP request handling for SRR API clients.
// Architecture:
// - Encapsulates token resolution, timeout guidance, and common error handling.
// Author: The Khatu Family Trust
// Copyright (c) The Khatu Family Trust
//
import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_exceptions.dart';

class SrrApiTransport {
  SrrApiTransport({required String baseUrl})
    : _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
      _http = http.Client();

  static const Duration _defaultRequestTimeout = Duration(seconds: 30);
  static const Duration _heavyRequestTimeout = Duration(seconds: 120);

  final Uri _baseUri;
  final http.Client _http;

  String get baseUrl {
    final value = _baseUri.toString();
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  Future<http.Response> send(
    String method,
    String path, {
    bool auth = false,
    Map<String, dynamic>? body,
  }) async {
    final url = _baseUri.resolve(
      path.startsWith('/') ? path.substring(1) : path,
    );
    final requestTimeout = _timeoutForPath(path);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
    };

    if (auth) {
      final token = await resolveAuthToken(forceRefresh: true);
      if (token == null) {
        throw const ApiException('You are not signed in.');
      }
      headers['Authorization'] = 'Bearer $token';
    } else {
      final token = await resolveAuthToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    late final http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _http
              .get(url, headers: headers)
              .timeout(requestTimeout);
          break;
        case 'POST':
          response = await _http
              .post(
                url,
                headers: headers,
                body: body == null ? null : json.encode(body),
              )
              .timeout(requestTimeout);
          break;
        case 'PATCH':
          response = await _http
              .patch(
                url,
                headers: headers,
                body: body == null ? null : json.encode(body),
              )
              .timeout(requestTimeout);
          break;
        case 'DELETE':
          response = await _http
              .delete(url, headers: headers)
              .timeout(requestTimeout);
          break;
        default:
          throw ApiException('Unsupported HTTP method: $method');
      }
    } on TimeoutException {
      throw ApiException(
        'Request timed out after ${requestTimeout.inSeconds}s. API endpoint: '
        '$baseUrl.$_timeoutGuidance',
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        'Network error: ${error.message}. API endpoint: $baseUrl',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }

    if (response.statusCode == 401 && auth) {
      await clearSession();
    }

    throw ApiException(
      _extractError(response),
      statusCode: response.statusCode,
    );
  }

  void dispose() {
    _http.close();
  }

  Future<void> clearSession() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // ignore
    }
  }

  Future<String?> resolveAuthToken({bool forceRefresh = false}) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return null;
    try {
      final firebaseToken = await firebaseUser.getIdToken(forceRefresh);
      final normalized = firebaseToken?.trim();
      if (normalized != null && normalized.isNotEmpty) {
        return normalized;
      }
    } on FirebaseAuthException {
      return null;
    }
    return null;
  }

  String _extractError(http.Response response) {
    try {
      final object = json.decode(response.body) as Map<String, dynamic>;
      final detail = object['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail;
      }
    } catch (_) {
      // ignore
    }
    return 'Request failed with status ${response.statusCode}.';
  }

  String get _timeoutGuidance {
    final host = _baseUri.host.trim().toLowerCase();
    final isLocalHost =
        host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '0.0.0.0' ||
        host == '10.0.2.2';
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        isLocalHost) {
      return ' On a physical Android phone, set SRR_API_URL to a reachable host (for example http://192.168.x.x:8000).';
    }
    return ' The server may be cold-starting or processing a large upload. Please retry.';
  }

  Duration _timeoutForPath(String path) {
    final normalizedPath = path.toLowerCase();
    if (normalizedPath.contains('/tournaments/') &&
        normalizedPath.contains('/players/upload')) {
      return _heavyRequestTimeout;
    }
    if (normalizedPath.contains('/rankings/upload')) {
      return _heavyRequestTimeout;
    }
    if (normalizedPath.contains('/tournament/setup')) {
      return _heavyRequestTimeout;
    }
    return _defaultRequestTimeout;
  }
}
