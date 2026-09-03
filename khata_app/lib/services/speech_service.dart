import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Result of a single speech recognition event.
///
/// Bundles the recognized text, an overall confidence score (0.0–1.0),
/// and whether this is the final result for the current listening session.
class SpeechResult {
  const SpeechResult({
    required this.text,
    required this.confidence,
    required this.isFinal,
  });

  final String text;
  final double confidence;
  final bool isFinal;
}

/// Handles speech-to-text initialization and listening.
///
/// This is a thin wrapper around the `speech_to_text` plugin so screens
/// do not depend directly on the plugin's API. Callers must still dispose
/// of listeners or callbacks they register.
class SpeechService {
  /// Internal plugin instance. Lazily created to avoid startup overhead.
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isAvailable = false;

  /// True when the device supports speech recognition.
  bool get isAvailable => _isAvailable;

  /// True while the service is actively listening.
  bool get isListening => _speech.isListening;

  /// Initializes the speech recognizer if it has not been initialized yet.
  ///
  /// Returns true when speech recognition is ready to use.
  Future<bool> initialize() async {
    if (_isAvailable) {
      debugPrint('[SpeechService] initialize: already initialized, skipping.');
      return true;
    }

    debugPrint('[SpeechService] initialize: starting plugin initialization...');
    _isAvailable = await _speech.initialize(
      onStatus: _onStatus,
      onError: _onError,
    );

    debugPrint(
      '[SpeechService] initialize: ${_isAvailable ? "succeeded" : "failed — speech recognition unavailable on this device"}.',
    );
    return _isAvailable;
  }

  /// Starts listening for voice input.
  ///
  /// [onResult] is called whenever partial or final results arrive with
  /// the recognized text and an overall confidence score.
  /// [localeId] can be used to select a language such as 'ur_PK'.
  Future<void> startListening({
    required void Function(SpeechResult result) onResult,
    String? localeId,
    Duration listenFor = const Duration(seconds: 15),
  }) async {
    if (!_isAvailable) {
      debugPrint(
        '[SpeechService] startListening: rejected — service not initialized.',
      );
      throw StateError('SpeechService has not been initialized.');
    }

    debugPrint(
      '[SpeechService] startListening: requesting listen '
      '(localeId: $localeId, listenFor: ${listenFor.inSeconds}s)...',
    );

    await _speech.listen(
      onResult: (result) {
        debugPrint(
          '[SpeechService] result: text="${result.recognizedWords}", '
          'confidence=${result.confidence}, isFinal=${result.finalResult}',
        );
        onResult(
          SpeechResult(
            text: result.recognizedWords,
            confidence: result.confidence.clamp(0.0, 1.0),
            isFinal: result.finalResult,
          ),
        );
      },
      listenOptions: stt.SpeechListenOptions(
        // TEMP: dictation mode for longer, natural speech during accuracy
        // testing; revert to ListenMode.confirmation afterwards.
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        localeId: localeId,
        listenFor: listenFor,
      ),
    );

    debugPrint('[SpeechService] startListening: listen session started.');
  }

  /// Stops the current listening session.
  Future<void> stopListening() async {
    await _speech.stop();
  }

  /// Cancels the current listening session without returning results.
  Future<void> cancelListening() async {
    await _speech.cancel();
  }

  /// Returns the list of locales supported by the speech recognizer.
  Future<List<stt.LocaleName>> getLocales() async {
    if (!_isAvailable) return [];
    return _speech.locales();
  }

  void _onStatus(String status) {
    debugPrint('[SpeechService] status: $status');
  }

  void _onError(Object error) {
    debugPrint('[SpeechService] error from plugin: $error');
  }
}
