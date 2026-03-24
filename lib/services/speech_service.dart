import 'dart:io';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  SpeechService._();

  static final SpeechService instance = SpeechService._();
  final SpeechToText _speechToText = SpeechToText();
  String? _lastInitError;
  bool _keepListening = false;
  bool _restartInProgress = false;
  String? _activeLocaleId;
  void Function(String text, bool isFinal)? _activeOnResult;
  void Function(bool isListening)? _activeOnListeningStateChanged;
  void Function(String message)? _activeOnError;

  bool get isListening => _speechToText.isListening;
  bool get isSupportedPlatform => !Platform.isWindows;
  String? get lastInitError => _lastInitError;

  String? get unsupportedReason {
    if (Platform.isWindows) {
      return 'El reconocimiento de voz en Windows presenta un fallo conocido del plugin. Usa Android/iOS para dictado o escribe manualmente.';
    }
    return null;
  }

  Future<bool> init() async {
    if (!isSupportedPlatform) {
      _lastInitError = unsupportedReason;
      return false;
    }

    try {
      final available = await _speechToText.initialize(
        onStatus: _handleEngineStatus,
        onError: _handleEngineError,
      );
      if (!available) {
        _lastInitError =
            'No se pudo iniciar el reconocimiento de voz. Revisa el permiso de micrófono y que el motor de voz del dispositivo esté disponible.';
        return false;
      }
      _lastInitError = null;
      return true;
    } catch (e) {
      _lastInitError = e.toString();
      return false;
    }
  }

  Future<String> resolveBestSpanishLocale() async {
    final locales = await _speechToText.locales();
    if (locales.isEmpty) return 'es_ES';

    const preferred = ['es_ES', 'es_MX', 'es_US', 'es_AR'];

    for (final localeId in preferred) {
      if (locales.any((locale) => locale.localeId == localeId)) {
        return localeId;
      }
    }

    final genericSpanish = locales.where((locale) => locale.localeId.startsWith('es_')).toList();
    if (genericSpanish.isNotEmpty) {
      return genericSpanish.first.localeId;
    }

    return 'es_ES';
  }

  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function(bool isListening) onListeningStateChanged,
    required void Function(String message) onError,
    String? localeId,
  }) async {
    if (!isSupportedPlatform) {
      onListeningStateChanged(false);
      onError(unsupportedReason ?? 'Reconocimiento de voz no disponible en esta plataforma.');
      return;
    }

    final selectedLocale = localeId ?? await resolveBestSpanishLocale();
    _keepListening = true;
    _restartInProgress = false;
    _activeLocaleId = selectedLocale;
    _activeOnResult = onResult;
    _activeOnListeningStateChanged = onListeningStateChanged;
    _activeOnError = onError;
    onListeningStateChanged(true);

    await _startListeningSession();
  }

  Future<void> _startListeningSession() async {
    final localeId = _activeLocaleId;
    final onResult = _activeOnResult;
    final onListeningStateChanged = _activeOnListeningStateChanged;
    final onError = _activeOnError;

    if (localeId == null || onResult == null || onListeningStateChanged == null || onError == null) {
      return;
    }

    try {
      await _speechToText.listen(
        localeId: localeId,
        listenFor: const Duration(minutes: 30),
        pauseFor: const Duration(seconds: 90),
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
        ),
        onResult: (SpeechRecognitionResult result) {
          if (_keepListening) {
            onListeningStateChanged(true);
          }
          onResult(result.recognizedWords, result.finalResult);

          if (result.finalResult) {
            _scheduleRestartIfNeeded();
          }
        },
      );
    } catch (e) {
      if (!_keepListening) return;
      onError(e.toString());
      _scheduleRestartIfNeeded();
    }
  }

  void _scheduleRestartIfNeeded() {
    if (!_keepListening || _restartInProgress) return;
    _restartInProgress = true;

    Future<void>.delayed(const Duration(milliseconds: 250), () async {
      if (!_keepListening) {
        _restartInProgress = false;
        return;
      }
      if (_speechToText.isListening) {
        _restartInProgress = false;
        return;
      }
      _restartInProgress = false;
      await _startListeningSession();
    });
  }

  void _handleEngineStatus(String status) {
    final normalized = status.toLowerCase();

    if (normalized == 'notlistening' || normalized == 'done') {
      if (_keepListening) {
        _activeOnListeningStateChanged?.call(true);
        _scheduleRestartIfNeeded();
      } else {
        _activeOnListeningStateChanged?.call(false);
      }
      return;
    }

    if (normalized == 'listening') {
      _activeOnListeningStateChanged?.call(true);
    }
  }

  void _handleEngineError(SpeechRecognitionError error) {
    if (!_keepListening) {
      _activeOnListeningStateChanged?.call(false);
      return;
    }

    final message = error.errorMsg.trim();
    final shouldSilenceMessage =
        message == 'error_no_match' ||
        message == 'error_speech_timeout' ||
        message == 'error_client';

    if (!shouldSilenceMessage && message.isNotEmpty) {
      _activeOnError?.call(message);
    }

    _scheduleRestartIfNeeded();
  }

  Future<void> stopListening() {
    _keepListening = false;
    _restartInProgress = false;
    _activeOnListeningStateChanged?.call(false);
    return _speechToText.stop();
  }
}
