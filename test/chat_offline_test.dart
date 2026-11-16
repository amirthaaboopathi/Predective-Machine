import 'package:flutter_test/flutter_test.dart';
import 'package:myappliance/services/gemini_chat_service.dart';
import 'package:myappliance/models/chat_message_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Master System Prompt & Dual-Mode Chatbot Verification', () {
    test('Master Chatbot responds with structured intelligence', () async {
      final chatService = GeminiChatService();

      // 1. Test Structured Health Assessment
      await chatService.sendMessage('Generate a health assessment report for my machine');
      expect(chatService.messages.length, greaterThanOrEqualTo(2));
      final healthMsg = chatService.messages.last;
      expect(healthMsg.isUser, false);
      expect(healthMsg.status, ChatMessageStatus.sent);
      expect(healthMsg.text.contains('APPLIANCE HEALTH STATUS:'), true);
      expect(healthMsg.text.contains('SENSOR ANALYSIS:'), true);
      expect(healthMsg.text.contains('POSSIBLE ISSUES:'), true);
      expect(healthMsg.text.contains('RECOMMENDED ACTION:'), true);

      // 2. Test Temperature Diagnostics
      await chatService.sendMessage('Is the temperature reading normal?');
      final tempMsg = chatService.messages.last;
      expect(tempMsg.isUser, false);
      expect(tempMsg.text.contains('temperature') || tempMsg.text.contains('°C'), true);
      expect(tempMsg.text.contains('20.0 °C') || tempMsg.text.contains('55.0 °C'), true);

      // 3. Test Vibration & Mechanical Diagnostics
      await chatService.sendMessage('Why is the machine vibrating?');
      final vibMsg = chatService.messages.last;
      expect(vibMsg.isUser, false);
      expect(vibMsg.text.contains('vibration') || vibMsg.text.contains('G'), true);

      // 4. Test Acoustic Sound Diagnostics
      await chatService.sendMessage('Is the sound level too loud?');
      final soundMsg = chatService.messages.last;
      expect(soundMsg.isUser, false);
      expect(soundMsg.text.contains('sound') || soundMsg.text.contains('dB'), true);

      // 5. Test Domain Restriction (Section 11)
      await chatService.sendMessage('Tell me who won the football world cup in 1998');
      final domainMsg = chatService.messages.last;
      expect(domainMsg.isUser, false);
      expect(domainMsg.text.contains('I am your specialized Appliance Health Monitoring Assistant'), true);
    });
  });
}
