import '/services/debug_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef STTResultCallback = void Function(String text, bool isFinal);
typedef VoskProgressCallback = void Function(int percent);

/// 對應 ScenarioRepository.kt，兩邊要同步。
class KebbiScenario {
  KebbiScenario._();

  // 管家
  static const welcome = 'butler_welcome';
  static const guide = 'butler_guide';
  static const thinking = 'butler_thinking';
  static const celebrate = 'butler_celebrate';
  static const farewell = 'butler_farewell';

  // 管家回覆情緒 (依後端 x-sentiment-label；設計依據 Dael 2012、Gao 2024)
  static const sentimentPositive = 'butler_sentiment_positive';
  static const sentimentNeutral = 'butler_sentiment_neutral';
  static const sentimentNegative = 'butler_sentiment_negative';

  // 管家互動時機 (Nuwa 內建動作 + 維持姿勢)
  /// 等回覆：思考姿勢維持到 [KebbiService.nextScenarioStep]
  static const thinkHold = 'butler_think_loop';

  /// 長輩說話：聆聽姿勢維持到 [KebbiService.nextScenarioStep]，再點頭
  static const listenHold = 'butler_listen_nod';

  /// 道別：揮手 + 開心表情
  static const byeHappy = 'butler_bye_happy';

  // 詐騙警告
  static const physicalBlock = 'fraud_physical_block';
  static const panic = 'fraud_panic';
  static const accuse = 'fraud_accuse';
  static const reject = 'fraud_reject';
  static const siren = 'fraud_siren';

  /// 全部動作跑一遍，用來確認硬體正常。
  static const fullDemo = 'mega_demo_60s';
}

class KebbiService {
  static const MethodChannel _ch = MethodChannel('kebbi');

  static bool get _isAndroidNative =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  // STT result callback — set by ButlerChatPage
  static STTResultCallback? _sttCallback;

  // Vosk download progress callback — set by ButlerChatPage
  static VoskProgressCallback? _voskProgressCallback;

  /// Wire up incoming method calls from native.
  /// Must be called once before using STT or Vosk.
  static void setupCallbackHandler() {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'onSTTResult') {
        final text = (call.arguments as Map)['text'] as String? ?? '';
        final isFinal = (call.arguments as Map)['isFinal'] as bool? ?? true;
        _sttCallback?.call(text, isFinal);
      } else if (call.method == 'onVoskProgress') {
        final percent = call.arguments as int? ?? 0;
        _voskProgressCallback?.call(percent);
      }
    });
  }

  static void setSTTCallback(STTResultCallback? cb) => _sttCallback = cb;
  static void setVoskProgressCallback(VoskProgressCallback? cb) =>
      _voskProgressCallback = cb;

  // ── Kebbi detection ────────────────────────────────────────────────────────

  /// Returns true if NuwaRobotAPI can be instantiated (i.e. running on Kebbi).
  static Future<bool> isKebbiAvailable() async {
    if (!_isAndroidNative) return false;
    try {
      final result = await _ch.invokeMethod<bool>('checkKebbi');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── Kebbi NuwaSDK STT ──────────────────────────────────────────────────────

  static Future<void> init() async {
    if (!_isAndroidNative) {
      DebugLogger.I.log(
          '[Kebbi] init skipped (${kIsWeb ? 'web' : defaultTargetPlatform.name})');
      return;
    }
    try {
      await _ch.invokeMethod<void>('init');
    } on MissingPluginException {
      DebugLogger.I.log('[Kebbi] init skipped: channel not registered.');
    } on PlatformException catch (e) {
      DebugLogger.I.log('[Kebbi] init error: ${e.code} ${e.message}');
    } catch (e) {
      DebugLogger.I.log('[Kebbi] init error: $e');
    }
  }

  static Future<void> startSTT() async {
    if (!_isAndroidNative) {
      DebugLogger.I.log('[Kebbi] startSTT skipped (not Android)');
      return;
    }
    try {
      await _ch.invokeMethod<void>('startSTT');
    } on MissingPluginException {
      DebugLogger.I.log('[Kebbi] startSTT skipped: channel not registered.');
    } on PlatformException catch (e) {
      DebugLogger.I.log('[Kebbi] startSTT error: ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      DebugLogger.I.log('[Kebbi] startSTT error: $e');
      rethrow;
    }
  }

  static Future<void> stopSTT() async {
    if (!_isAndroidNative) return;
    try {
      await _ch.invokeMethod<void>('stopSTT');
    } on MissingPluginException {
      DebugLogger.I.log('[Kebbi] stopSTT skipped.');
    } on PlatformException catch (e) {
      DebugLogger.I.log('[Kebbi] stopSTT error: ${e.code} ${e.message}');
    } catch (e) {
      DebugLogger.I.log('[Kebbi] stopSTT error: $e');
    }
  }

  // ── Vosk offline STT ───────────────────────────────────────────────────────

  /// Returns true if the Vosk model has already been downloaded.
  static Future<bool> isVoskModelReady() async {
    if (!_isAndroidNative) return false;
    try {
      final result = await _ch.invokeMethod<bool>('checkVoskModel');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Download (if needed) + load the Vosk model.
  /// Progress is reported via [setVoskProgressCallback]:
  ///   0–100 = download %, -1 = extracting.
  /// Throws on failure.
  static Future<void> initVosk() async {
    if (!_isAndroidNative) return;
    try {
      await _ch.invokeMethod<void>('initVosk');
    } on PlatformException catch (e) {
      DebugLogger.I.log('[Kebbi] initVosk error: ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      DebugLogger.I.log('[Kebbi] initVosk error: $e');
      rethrow;
    }
  }

  static Future<void> startVoskSTT() async {
    if (!_isAndroidNative) return;

    // Auto-init if model exists on disk but wasn't loaded (e.g., app restart)
    final ready = await isVoskModelReady();
    if (ready) {
      try {
        await initVosk();
      } catch (_) {}
    }

    try {
      await _ch.invokeMethod<void>('startVoskSTT');
    } on PlatformException catch (e) {
      DebugLogger.I.log('[Kebbi] startVoskSTT error: ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      DebugLogger.I.log('[Kebbi] startVoskSTT error: $e');
      rethrow;
    }
  }

  static Future<void> stopVoskSTT() async {
    if (!_isAndroidNative) return;
    try {
      await _ch.invokeMethod<void>('stopVoskSTT');
    } catch (e) {
      DebugLogger.I.log('[Kebbi] stopVoskSTT error: $e');
    }
  }

  // ── Robot actions ──────────────────────────────────────────────────────────

  static Future<void> doFraudAction() async {
    if (!_isAndroidNative) return;
    try {
      await _ch.invokeMethod<void>('fraud');
    } on MissingPluginException {
      DebugLogger.I.log('[Kebbi] fraud skipped: channel not registered.');
    } on PlatformException catch (e) {
      DebugLogger.I.log('[Kebbi] fraud error: ${e.code} ${e.message}');
    } catch (e) {
      DebugLogger.I.log('[Kebbi] fraud error: $e');
    }
  }

  static Future<void> doSafeAction() async {
    if (!_isAndroidNative) return;
    try {
      await _ch.invokeMethod<void>('safe');
    } on MissingPluginException {
      DebugLogger.I.log('[Kebbi] safe skipped: channel not registered.');
    } on PlatformException catch (e) {
      DebugLogger.I.log('[Kebbi] safe error: ${e.code} ${e.message}');
    } catch (e) {
      DebugLogger.I.log('[Kebbi] safe error: $e');
    }
  }

  /// 若已有動作在播，會先停掉再播新的 (原生層處理)。
  /// 回傳 false 表示沒播：不在凱比上或發生錯誤。不會丟例外。
  static Future<bool> playScenario(String id) async {
    if (!_isAndroidNative) return false;
    try {
      final started =
          await _ch.invokeMethod<bool>('playScenario', {'id': id});
      return started ?? false;
    } on MissingPluginException {
      DebugLogger.I.log('[Kebbi] playScenario skipped: channel not registered.');
      return false;
    } on PlatformException catch (e) {
      DebugLogger.I.log('[Kebbi] playScenario($id) error: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      DebugLogger.I.log('[Kebbi] playScenario($id) error: $e');
      return false;
    }
  }

  /// 目前沒在播就立刻播；正在播就等它播完再播 (只保留最後一個排隊的)。
  /// 回傳 false 表示沒播：不在凱比上或發生錯誤。不會丟例外。
  static Future<bool> playScenarioAfterCurrent(String id) async {
    if (!_isAndroidNative) return false;
    try {
      final ok = await _ch
          .invokeMethod<bool>('playScenarioAfterCurrent', {'id': id});
      return ok ?? false;
    } on MissingPluginException {
      DebugLogger.I.log('[Kebbi] playScenarioAfterCurrent skipped: channel not registered.');
      return false;
    } catch (e) {
      DebugLogger.I.log('[Kebbi] playScenarioAfterCurrent($id) error: $e');
      return false;
    }
  }

  /// 結束目前的「維持姿勢」(思考：回覆到了；聆聽：長輩說完了)，
  /// 讓動作播完回到立正再進下一步。沒有在維持時回傳 false。
  static Future<bool> nextScenarioStep() async {
    if (!_isAndroidNative) return false;
    try {
      return await _ch.invokeMethod<bool>('nextScenarioStep') ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      DebugLogger.I.log('[Kebbi] nextScenarioStep error: $e');
      return false;
    }
  }

  /// 停止播放並復原硬體。
  static Future<void> stopScenario() async {
    if (!_isAndroidNative) return;
    try {
      await _ch.invokeMethod<void>('stopScenario');
    } catch (e) {
      DebugLogger.I.log('[Kebbi] stopScenario error: $e');
    }
  }

  static Future<bool> isScenarioPlaying() async {
    if (!_isAndroidNative) return false;
    try {
      return await _ch.invokeMethod<bool>('isScenarioPlaying') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 預設關閉。動作會讓凱比以約 0.3 m/s 移動，放在桌上會掉下去。
  /// 手臂、燈光、音效不受影響。
  static Future<void> setChassisEnabled(bool enabled) async {
    if (!_isAndroidNative) return;
    try {
      await _ch.invokeMethod<bool>('setChassisEnabled', {'enabled': enabled});
    } catch (e) {
      DebugLogger.I.log('[Kebbi] setChassisEnabled error: $e');
    }
  }

  static Future<void> release() async {
    if (!_isAndroidNative) return;
    try {
      await _ch.invokeMethod<void>('release');
    } on MissingPluginException {
      DebugLogger.I.log('[Kebbi] release skipped: channel not registered.');
    } on PlatformException catch (e) {
      DebugLogger.I.log('[Kebbi] release error: ${e.code} ${e.message}');
    } catch (e) {
      DebugLogger.I.log('[Kebbi] release error: $e');
    }
  }
}
