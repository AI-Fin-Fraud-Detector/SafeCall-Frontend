import 'package:flutter/foundation.dart';

class DebugLogger {
  DebugLogger._();
  static final DebugLogger I = DebugLogger._();

  static const int _maxEntries = 300;

  final ValueNotifier<List<String>> entries = ValueNotifier(const []);

  void log(String message) {
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final line = '[$ts] $message';
    debugPrint('[DBG] $message');
    final updated = [...entries.value, line];
    entries.value = updated.length > _maxEntries
        ? updated.sublist(updated.length - _maxEntries)
        : updated;
  }

  void clear() => entries.value = const [];

  String get allText => entries.value.join('\n');
}
