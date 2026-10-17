import '/services/debug_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

typedef STTCallback = void Function(String text, bool isFinal);

/// Platform speech recognition via the speech_to_text package
/// (Web Speech API on web, Android SpeechRecognizer on Android).
class SpeechService {
  static final SpeechService I = SpeechService._();

  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  STTCallback? _callback;

  SpeechService._();

  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onStatus: (status) {
        DebugLogger.I.log('[Speech] Status: $status');
      },
      onError: (error) {
        DebugLogger.I.log('[Speech] Error: $error');
        _callback?.call('', true);
      },
    );
    DebugLogger.I.log('[Speech] Initialized: $_initialized');
    return _initialized;
  }

  void setCallback(STTCallback? cb) {
    _callback = cb;
  }

  Future<bool> startListening() async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return false;
    }

    return await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        final text = result.recognizedWords;
        final isFinal = result.finalResult;
        _callback?.call(text, isFinal);
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_US',
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
      ),
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }

  bool get isListening => _speech.isListening;

  bool get isAvailable => _initialized;
}
