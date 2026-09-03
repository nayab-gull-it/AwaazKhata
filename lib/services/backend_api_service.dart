import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:khata_app/config/app_config.dart';
import 'package:khata_app/models/parsed_action.dart';

/// Communicates with the AwaazKhata backend.
///
/// The Flutter app never calls Qwen or any other AI service directly.
/// All AI processing is delegated to the backend, which keeps API keys
/// and prompts out of the mobile client.
class BackendApiService {
  /// HTTP client used for backend requests.
  ///
  /// Kept injectable so tests can supply a mock client.
  final http.Client _client;

  BackendApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Sends a raw voice transcript to the backend for intent parsing.
  ///
  /// Returns a typed [ParsedAction] on success. Throws [BackendException]
  /// when the backend is unreachable, times out, or returns a non-2xx
  /// status code.
  Future<ParsedAction> parseVoiceCommand(String transcript) async {
    final uri = Uri.parse('${AppConfig.backendBaseUrl}/parse-command');

    debugPrint('[BackendApi] POST $uri transcript="$transcript"');

    http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'transcript': transcript}),
          )
          .timeout(AppConfig.backendTimeout);
    } on SocketException catch (e) {
      debugPrint('[BackendApi] SocketException: $e');
      throw const BackendException(
        "Couldn't reach the server. Is the backend running?",
      );
    } on TimeoutException catch (e) {
      debugPrint('[BackendApi] TimeoutException: $e');
      throw const BackendException(
        'The server took too long to respond. Try again.',
      );
    } on HttpException catch (e) {
      debugPrint('[BackendApi] HttpException: $e');
      throw BackendException('Network error: ${e.message}');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint(
        '[BackendApi] HTTP ${response.statusCode}: ${response.body}',
      );
      throw BackendException(
        'Server returned ${response.statusCode}. Try again.',
      );
    }

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint('[BackendApi] Parsed response: $json');
      return ParsedAction.fromJson(json);
    } on FormatException catch (e) {
      debugPrint('[BackendApi] FormatException: $e');
      throw const BackendException(
        "Couldn't understand the server response.",
      );
    }
  }
}

/// Thrown when the backend is unreachable, times out, or returns an error.
///
/// Carries a user-friendly message suitable for display in a SnackBar.
class BackendException implements Exception {
  const BackendException(this.message);

  final String message;

  @override
  String toString() => 'BackendException: $message';
}
