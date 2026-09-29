import 'kebbi_service.dart';
import 'debug_logger.dart';

/// 決定凱比在詐騙來電中要做什麼動作。
///
/// 兩個來源：後端的判定事件優先，會打斷正在播的動作；詐騙者講的關鍵字次之，
/// 只在沒有動作在播時才觸發。全部不會丟例外，機器人不動也不該影響通話。
class RobotActionService {
  RobotActionService._();

  /// 詐騙者會講的話。由上往下比對，第一個命中的就用。
  static const List<_Rule> _rules = [
    // 直接要錢
    _Rule(KebbiScenario.siren, [
      'transfer the money',
      'transfer money',
      'wire the money',
      'send me the money',
      'send the money',
      'pay the fine',
      'pay it now',
    ]),

    // 要帳號、密碼、驗證碼
    _Rule(KebbiScenario.reject, [
      'account number',
      'bank account',
      'credit card number',
      'verification code',
      'one-time password',
      'your password',
      'gift card',
      'bitcoin',
    ]),

    // 冒充身分
    _Rule(KebbiScenario.accuse, [
      'this is the police',
      'i am the police',
      'police officer',
      'this is the bank',
      'from the bank',
      'tax office',
      'government agency',
      'prosecutor',
    ]),

    // 要求安裝程式或開放存取
    _Rule(KebbiScenario.physicalBlock, [
      'install this app',
      'install the app',
      'download this app',
      'click the link',
      'remote access',
      'give me access',
    ]),

    // 威脅與催促
    _Rule(KebbiScenario.panic, [
      'you will be arrested',
      'account has been frozen',
      'account is frozen',
      'do not tell anyone',
      "don't tell anyone",
      'last warning',
      'right now or',
    ]),
  ];

  /// 後端判定為詐騙。最高優先，打斷正在播的動作。
  static void onFraudAlert() {
    _play(KebbiScenario.siren, interrupt: true);
  }

  /// 後端判定可以安心接。
  static void onSafeToAnswer() {
    _play(KebbiScenario.welcome, interrupt: true);
  }

  /// 詐騙者講了一句話。沒有關鍵字命中就不動。
  static void reactToCaller(String text) {
    final id = scenarioFor(text);
    if (id == null) return;
    _play(id, interrupt: false);
  }

  static void stop() {
    KebbiService.stopScenario();
  }

  /// 公開出來是為了不用機器人也能測。
  static String? scenarioFor(String text) {
    if (text.trim().isEmpty) return null;
    // 語音轉出來可能用彎引號的撇號
    final haystack = text.toLowerCase().replaceAll('’', "'");

    for (final rule in _rules) {
      for (final keyword in rule.keywords) {
        if (_containsWord(haystack, keyword)) return rule.scenarioId;
      }
    }
    return null;
  }

  /// 只比對整個字，"bank account" 不會在 "bank accounts" 之外亂命中。
  static bool _containsWord(String haystack, String keyword) {
    final pattern = RegExp(
      r'\b' + RegExp.escape(keyword) + r'\b',
      caseSensitive: false,
    );
    return pattern.hasMatch(haystack);
  }

  static void _play(String id, {required bool interrupt}) {
    Future(() async {
      try {
        if (interrupt) {
          await KebbiService.stopScenario();
        } else if (await KebbiService.isScenarioPlaying()) {
          // 後端的警報還在播，不要蓋掉
          DebugLogger.I.log('[RobotAction] busy, skipped $id');
          return;
        }
        final started = await KebbiService.playScenario(id);
        if (!started) {
          DebugLogger.I.log('[RobotAction] $id not started');
        }
      } catch (e) {
        DebugLogger.I.log('[RobotAction] $id failed: $e');
      }
    });
  }
}

class _Rule {
  const _Rule(this.scenarioId, this.keywords);

  final String scenarioId;
  final List<String> keywords;
}
