import 'package:flutter_test/flutter_test.dart';
import 'package:fraud_detect_app/services/kebbi_service.dart';
import 'package:fraud_detect_app/services/robot_action_service.dart';

void main() {
  group('RobotActionService.scenarioFor', () {
    test('空字串不觸發', () {
      expect(RobotActionService.scenarioFor(''), isNull);
      expect(RobotActionService.scenarioFor('   '), isNull);
    });

    test('沒有關鍵字的閒聊不觸發', () {
      expect(
        RobotActionService.scenarioFor('Good morning, how are you today?'),
        isNull,
      );
    });

    test('直接要錢優先於其他', () {
      expect(
        RobotActionService.scenarioFor(
          'This is the police, you must transfer the money now.',
        ),
        KebbiScenario.siren,
      );
    });

    test('要帳號優先於冒充身分', () {
      expect(
        RobotActionService.scenarioFor(
          'I am from the bank, give me your account number.',
        ),
        KebbiScenario.reject,
      );
    });

    test('冒充身分', () {
      expect(
        RobotActionService.scenarioFor('Hello, this is the police.'),
        KebbiScenario.accuse,
      );
    });

    test('要求安裝程式', () {
      expect(
        RobotActionService.scenarioFor('Please install this app to verify.'),
        KebbiScenario.physicalBlock,
      );
    });

    test('威脅與催促', () {
      expect(
        RobotActionService.scenarioFor('You will be arrested today.'),
        KebbiScenario.panic,
      );
      expect(
        RobotActionService.scenarioFor('Do not tell anyone about this.'),
        KebbiScenario.panic,
      );
    });

    test('彎引號的撇號也要命中', () {
      expect(
        RobotActionService.scenarioFor('Don’t tell anyone.'),
        KebbiScenario.panic,
      );
    });

    test('大小寫不影響', () {
      expect(
        RobotActionService.scenarioFor('TRANSFER THE MONEY'),
        KebbiScenario.siren,
      );
    });

    test('只比對整個字', () {
      expect(RobotActionService.scenarioFor('I like bitcoins'), isNull);
    });
  });
}
