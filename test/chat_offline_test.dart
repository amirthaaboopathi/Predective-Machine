import 'package:flutter_test/flutter_test.dart';
import 'package:myappliance/services/gemini_chat_service.dart';
import 'package:myappliance/models/chat_message_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Chatbot Dual-Mode Offline & Online Resilience', () {
    test('Chatbot responds immediately without internet connection', () async {
      final chatService = GeminiChatService();

      // Test general health check query
      await chatService.sendMessage('How is my refrigerator performing?');

      expect(chatService.messages.length, greaterThanOrEqualTo(2));
      final lastMsg = chatService.messages.last;
      expect(lastMsg.isUser, false);
      expect(lastMsg.text.isNotEmpty, true);
      expect(lastMsg.status, ChatMessageStatus.sent);
      expect(lastMsg.text.contains('Operating Assessment') || lastMsg.text.contains('Telemetry'), true);

      // Test temperature query
      await chatService.sendMessage('Is the temperature normal?');
      final tempMsg = chatService.messages.last;
      expect(tempMsg.isUser, false);
      expect(tempMsg.text.contains('Temperature') || tempMsg.text.contains('°C'), true);

      // Test vibration query
      await chatService.sendMessage('Why is vibration shaking?');
      final vibMsg = chatService.messages.last;
      expect(vibMsg.isUser, false);
      expect(vibMsg.text.contains('Vibration') || vibMsg.text.contains('G'), true);

      // Test sound query
      await chatService.sendMessage('Is it making loud noise?');
      final soundMsg = chatService.messages.last;
      expect(soundMsg.isUser, false);
      expect(soundMsg.text.contains('Sound') || soundMsg.text.contains('dB'), true);
    });
  });
}

