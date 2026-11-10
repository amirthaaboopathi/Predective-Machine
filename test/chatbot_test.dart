import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myappliance/models/chat_message_model.dart';
import 'package:myappliance/models/appliance_model.dart';
import 'package:myappliance/services/gemini_chat_service.dart';
import 'package:myappliance/widgets/chat_markdown_view.dart';
import 'package:myappliance/app/routes.dart';

void main() {
  group('ChatMessage Model Tests', () {
    test('Creates ChatMessage and serializes to/from map', () {
      final now = DateTime.now();
      final message = ChatMessage(
        id: 'msg-1',
        text: 'How is my refrigerator performing?',
        isUser: true,
        timestamp: now,
        status: ChatMessageStatus.sent,
        referencedApplianceId: 'app-1',
        referencedApplianceName: 'LG Refrigerator',
        suggestedActions: ['Check temperature', 'Run diagnostic'],
      );

      expect(message.id, 'msg-1');
      expect(message.isUser, isTrue);
      expect(message.referencedApplianceName, 'LG Refrigerator');

      final map = message.toMap();
      expect(map['text'], 'How is my refrigerator performing?');
      expect(map['isUser'], true);
      expect(map['referencedApplianceId'], 'app-1');

      final deserialized = ChatMessage.fromMap(map);
      expect(deserialized.id, 'msg-1');
      expect(deserialized.text, message.text);
      expect(deserialized.isUser, isTrue);
      expect(deserialized.referencedApplianceName, 'LG Refrigerator');
      expect(deserialized.suggestedActions?.length, 2);
    });

    test('copyWith works accurately', () {
      final msg = ChatMessage(
        id: '1',
        text: 'Initial',
        isUser: true,
        timestamp: DateTime.now(),
      );

      final updated = msg.copyWith(text: 'Modified text');
      expect(updated.text, 'Modified text');
      expect(updated.id, '1');
      expect(updated.isUser, isTrue);
    });
  });

  group('GeminiChatService Tests', () {
    test('Initializes with welcome message and suggested questions', () {
      final service = GeminiChatService();
      expect(service.messages, isNotEmpty);
      expect(service.messages.first.isUser, isFalse);

      final suggestions = service.getSuggestedQuestions();
      expect(suggestions, isNotEmpty);
    });

    test('Scoped appliance updates context suggestions', () {
      final service = GeminiChatService();
      final appliance = ApplianceModel(
        id: 'app-99',
        userId: 'user-1',
        name: 'Smart Air Conditioner',
        type: 'Air Conditioner',
        brand: 'Daikin',
        modelNumber: 'DK-200',
        addedAt: DateTime.now(),
      );

      service.setScopedAppliance(appliance);
      expect(service.scopedAppliance?.name, 'Smart Air Conditioner');

      final scopedSuggestions = service.getSuggestedQuestions();
      expect(
        scopedSuggestions.any((s) => s.contains('Smart Air Conditioner')),
        isTrue,
      );

      // Clear scope
      service.setScopedAppliance(null);
      expect(service.scopedAppliance, isNull);
    });

    test('clearChat resets message state', () {
      final service = GeminiChatService();
      service.clearChat();
      expect(service.messages.length, 1);
      expect(service.messages.first.id.startsWith('welcome-'), isTrue);
    });
  });

  group('ChatMarkdownView Widget Tests', () {
    testWidgets('Renders headers, bold text, and bullet points',
        (WidgetTester tester) async {
      const sampleMarkdown =
          '### Refrigerator Tips\n'
          'Here are **important** maintenance tips:\n'
          '* Clean the condenser coils\n'
          '* Check door gasket seals\n'
          '1. Set temperature to 37°F\n'
          '2. Avoid overcrowding shelves';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatMarkdownView(text: sampleMarkdown),
          ),
        ),
      );

      expect(find.text('Refrigerator Tips'), findsOneWidget);
      expect(find.byType(ChatMarkdownView), findsOneWidget);
    });
  });

  group('AppRoutes Tests', () {
    test('AppRoutes.chatbot constant is defined correctly', () {
      expect(AppRoutes.chatbot, '/chatbot');
    });
  });
}
