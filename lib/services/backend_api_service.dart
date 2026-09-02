import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:khata_app/config/app_config.dart';

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
  /// The backend is responsible for interpreting the Urdu command
  /// and returning a structured action (add inventory, record udhaar, etc.).
  Future<Map<String, dynamic>> processVoiceCommand(String transcript) async {
    final uri = Uri.parse('${AppConfig.backendBaseUrl}/voice/command');
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'transcript': transcript}),
        )
        .timeout(AppConfig.backendTimeout);

    return _handleResponse(response);
  }

  /// Fetches the current inventory list from the backend.
  Future<List<dynamic>> fetchInventory() async {
    final uri = Uri.parse('${AppConfig.backendBaseUrl}/inventory');
    final response = await _client
        .get(uri)
        .timeout(AppConfig.backendTimeout);

    final data = _handleResponse(response);
    return data['items'] as List<dynamic>? ?? [];
  }

  /// Fetches all udhaar (credit) entries from the backend.
  Future<List<dynamic>> fetchUdhaar() async {
    final uri = Uri.parse('${AppConfig.backendBaseUrl}/udhaar');
    final response = await _client
        .get(uri)
        .timeout(AppConfig.backendTimeout);

    final data = _handleResponse(response);
    return data['entries'] as List<dynamic>? ?? [];
  }

  /// Fetches all tasks from the backend.
  Future<List<dynamic>> fetchTasks() async {
    final uri = Uri.parse('${AppConfig.backendBaseUrl}/tasks');
    final response = await _client
        .get(uri)
        .timeout(AppConfig.backendTimeout);

    final data = _handleResponse(response);
    return data['tasks'] as List<dynamic>? ?? [];
  }

  /// Parses backend responses and throws a descriptive exception on failures.
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body;
    }

    throw HttpException(
      'Backend request failed: ${response.statusCode} ${response.body}',
      uri: response.request?.url,
    );
  }
}
