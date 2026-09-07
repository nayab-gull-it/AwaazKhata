import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Thin wrapper around the `flutter_tts` plugin so dialogs and screens can
/// speak short answer lines without depending on the plugin API directly.
class TtsService {
  TtsService._();

  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  /// Prepares the TTS engine. Safe to call repeatedly; the first call
  /// configures language and await-speak behavior.
  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _initialized = true;
      return true;
    } catch (e) {
      debugPrint('[TtsService] initialize failed: $e');
      return false;
    }
  }

  /// Speaks [text] aloud. Silently does nothing if TTS is unavailable —
  /// the visual answer is always the primary feedback channel.
  Future<void> speak(String text) async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return;
    }
    try {
      final clean = text
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (clean.isEmpty) return;
      await _tts.speak(clean);
    } catch (e) {
      debugPrint('[TtsService] speak failed: $e');
    }
  }

  /// Stops any ongoing speech (e.g. when the answer dialog closes).
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('[TtsService] stop failed: $e');
    }
  }
}
