import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/chat_message_model.dart';
import '../models/appliance_model.dart';
import '../utils/constants.dart';
import 'appliance_service.dart';
import 'sensor_service.dart';
import 'analysis_service.dart';
import 'auth_service.dart';

/// Service managing the Gemini AI Chatbot conversation, multi-turn state,
/// and live appliance telemetry context injection.
class GeminiChatService extends ChangeNotifier {
  static final GeminiChatService _instance = GeminiChatService._internal();
  factory GeminiChatService() => _instance;
  GeminiChatService._internal() {
    _initializeChat();
  }

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _errorMessage;
  ApplianceModel? _scopedAppliance;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ApplianceModel? get scopedAppliance => _scopedAppliance;

  void _initializeChat() {
    if (_messages.isEmpty) {
      _messages.add(
        ChatMessage(
          id: 'welcome-${DateTime.now().millisecondsSinceEpoch}',
          text: 'Hello! I am your **Appliance AI Assistant** powered by Google Gemini.\n\n'
              'I have real-time access to your registered appliances, sensor readings (temperature, vibration, sound), '
              'and diagnostic reports. Ask me anything about troubleshooting, maintenance tips, or appliance health!',
          isUser: false,
          timestamp: DateTime.now(),
          suggestedActions: getSuggestedQuestions(),
        ),
      );
    }
  }

  /// Sets or clears an active appliance filter for focused context in chat.
  void setScopedAppliance(ApplianceModel? appliance) {
    if (_scopedAppliance?.id != appliance?.id) {
      _scopedAppliance = appliance;
      notifyListeners();
    }
  }

  /// Resets the conversation back to the default welcome message.
  void clearChat() {
    _messages.clear();
    _errorMessage = null;
    _initializeChat();
    notifyListeners();
  }

  /// Returns contextual suggested prompt questions based on user's appliances.
  List<String> getSuggestedQuestions() {
    final appliances = ApplianceService().appliances;

    if (_scopedAppliance != null) {
      final name = _scopedAppliance!.name;
      final type = _scopedAppliance!.type;
      return [
        'How healthy is my $name right now?',
        'What are the best maintenance tips for this $type?',
        'What temperature and vibration are normal for my $name?',
        'Troubleshoot common issues with $type',
      ];
    }

    if (appliances.isNotEmpty) {
      final first = appliances.first;
      return [
        'Give me a health checkup of all my appliances',
        'How is my ${first.name} performing?',
        'How do I reduce my home appliances energy consumption?',
        'What should I do if an appliance overheats or vibrates?',
      ];
    }

    return [
      'How does the Appliance Health Checker work?',
      'What are normal sensor ranges for refrigerator and AC?',
      'How to prevent premature appliance breakdowns?',
      'Why does vibration and noise increase in washing machines?',
    ];
  }

  /// Sends a user message to Gemini with full appliance context and multi-turn history.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading) return;

    final userMessage = ChatMessage(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      text: trimmed,
      isUser: true,
      timestamp: DateTime.now(),
      status: ChatMessageStatus.sent,
      referencedApplianceId: _scopedAppliance?.id,
      referencedApplianceName: _scopedAppliance?.name,
    );

    _messages.add(userMessage);
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final responseText = await _callGeminiApi();

      final aiMessage = ChatMessage(
        id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
        text: responseText,
        isUser: false,
        timestamp: DateTime.now(),
        status: ChatMessageStatus.sent,
        referencedApplianceId: _scopedAppliance?.id,
        referencedApplianceName: _scopedAppliance?.name,
        suggestedActions: getSuggestedQuestions(),
      );

      _messages.add(aiMessage);
    } catch (e) {
      _errorMessage = 'Failed to get AI response: $e';
      _messages.add(
        ChatMessage(
          id: 'error-${DateTime.now().millisecondsSinceEpoch}',
          text: '⚠️ Sorry, I could not complete your request: $e\n\nPlease check your internet connection and try again.',
          isUser: false,
          timestamp: DateTime.now(),
          status: ChatMessageStatus.error,
        ),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Retries sending the last user message if the previous turn failed.
  Future<void> retryLastMessage() async {
    final lastUserMsgIndex = _messages.lastIndexWhere((m) => m.isUser);
    if (lastUserMsgIndex == -1) return;

    final lastUserMsg = _messages[lastUserMsgIndex];
    // Remove trailing error messages if any
    _messages.removeWhere((m) => m.status == ChatMessageStatus.error);
    notifyListeners();

    await sendMessage(lastUserMsg.text);
  }

  /// Internal call to Google Gemini REST API.
  Future<String> _callGeminiApi() async {
    final uri = Uri.parse(
      '${AppConstants.geminiBaseUrl}/${AppConstants.geminiModel}:generateContent?key=${AppConstants.geminiApiKey}',
    );

    final systemInstruction = _buildSystemInstruction();

    // Prepare conversation history (exclude welcome and error messages)
    final conversationTurns = <Map<String, dynamic>>[];
    for (final msg in _messages) {
      if (msg.status == ChatMessageStatus.error) continue;
      // Skip the very first welcome message if it's artificial
      if (msg.id.startsWith('welcome-')) continue;

      conversationTurns.add({
        'role': msg.isUser ? 'user' : 'model',
        'parts': [
          {'text': msg.text}
        ],
      });
    }

    // Safety fallback: if conversationTurns is empty, send the last user message
    if (conversationTurns.isEmpty && _messages.isNotEmpty) {
      conversationTurns.add({
        'role': 'user',
        'parts': [
          {'text': _messages.last.text}
        ],
      });
    }

    final payload = {
      'contents': conversationTurns,
      'systemInstruction': {
        'parts': [
          {'text': systemInstruction}
        ]
      },
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 1200,
      },
    };

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final candidates = data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'];
        final parts = content['parts'] as List?;
        if (parts != null && parts.isNotEmpty) {
          final text = parts[0]['text']?.toString() ?? '';
          if (text.isNotEmpty) {
            return text;
          }
        }
      }
      return 'Received an empty response from the AI assistant.';
    } else {
      String errorDetail = 'Status code ${response.statusCode}';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData['error'] != null && errorData['error']['message'] != null) {
          errorDetail = errorData['error']['message'];
        }
      } catch (_) {}
      throw Exception(errorDetail);
    }
  }

  /// Builds context-rich system instructions containing registered appliances,
  /// real sensor metrics, health thresholds, and diagnostic findings.
  String _buildSystemInstruction() {
    final user = AuthService().currentUser;
    final appliances = ApplianceService().appliances;
    final sensorService = SensorService();
    final analysisService = AnalysisService();

    final buffer = StringBuffer();
    buffer.writeln(
      'You are the expert Appliance AI Assistant embedded inside the "MyAppliance" mobile application. '
      'Your role is to help users maintain, troubleshoot, optimize, and diagnose their home appliances.',
    );
    buffer.writeln();

    if (user != null) {
      buffer.writeln('### Current User');
      buffer.writeln('- Name: ${user.displayName}');
      buffer.writeln('- Email: ${user.email}');
      buffer.writeln();
    }

    if (_scopedAppliance != null) {
      buffer.writeln('### Focus Appliance');
      buffer.writeln(
        'The user is currently inquiring specifically about: "${_scopedAppliance!.name}" '
        '(Type: ${_scopedAppliance!.type}, Brand: ${_scopedAppliance!.brand ?? "N/A"}, '
        'Model: ${_scopedAppliance!.modelNumber ?? "N/A"}).',
      );
      buffer.writeln();
    }

    buffer.writeln('### User\'s Registered Appliances and Live Telemetry');
    if (appliances.isEmpty) {
      buffer.writeln('The user has not registered any appliances in the app yet.');
    } else {
      for (final app in appliances) {
        final metrics = sensorService.getHealthMetricsForAppliance(app.id, app.name);
        final latestAnalysis = analysisService.getLatestAnalysisForAppliance(app.id);

        buffer.writeln('#### Appliance: ${app.name} (${app.type})');
        buffer.writeln('- ID: ${app.id}');
        buffer.writeln('- Brand: ${app.brand ?? "Unknown"}');
        buffer.writeln('- Model Number: ${app.modelNumber ?? "Unknown"}');
        buffer.writeln('- Purchase Date: ${app.purchaseDate ?? "Unknown"}');

        if (metrics.readingCount > 0) {
          buffer.writeln('- Live Sensor Telemetry:');
          buffer.writeln('  * Average Temperature: ${metrics.averageTemperature}°C (Health Score: ${metrics.temperatureHealth}%)');
          buffer.writeln('  * Average Vibration: ${metrics.averageVibration} (Health Score: ${metrics.vibrationHealth}%)');
          buffer.writeln('  * Average Sound: ${metrics.averageSound} dB (Health Score: ${metrics.soundHealth}%)');
          buffer.writeln('  * Overall Sensor Health Score: ${metrics.overallHealthScore?.round() ?? "N/A"}%');
          buffer.writeln('  * Health Status: ${metrics.healthStatus}');
          buffer.writeln('  * Reading Samples: ${metrics.readingCount}');
        } else {
          buffer.writeln('- Live Sensor Telemetry: No sensor telemetry recorded yet for this appliance.');
        }

        if (latestAnalysis != null) {
          buffer.writeln('- Latest Diagnostic Scan:');
          buffer.writeln('  * Condition: ${latestAnalysis.healthCondition}');
          buffer.writeln('  * Issues: ${latestAnalysis.detectedIssues.join(", ")}');
          buffer.writeln('  * Recommended Action: ${latestAnalysis.recommendedAction}');
        }
        buffer.writeln();
      }
    }

    buffer.writeln('### Appliance Health Reference Standards & Thresholds');
    buffer.writeln('- Temperature Benchmark:');
    buffer.writeln('  * 20°C to 60°C: Optimal / Healthy (100% score)');
    buffer.writeln('  * 60°C to 80°C: Elevated temperature warning (Score decreases proportionally)');
    buffer.writeln('  * > 80°C: Critical Overheating hazard (0% score)');
    buffer.writeln('- Vibration Benchmark:');
    buffer.writeln('  * 0.10 to 0.40: Optimal balance / Healthy (100% score)');
    buffer.writeln('  * 0.40 to 1.00: Moderate abnormal vibration (Score decreases proportionally)');
    buffer.writeln('  * > 1.00: Severe mechanical imbalance or loose component (0% score)');
    buffer.writeln('- Sound Benchmark:');
    buffer.writeln('  * 30 dB to 60 dB: Quiet to normal ambient operation (100% score)');
    buffer.writeln('  * 60 dB to 90 dB: Elevated operational noise (Score decreases proportionally)');
    buffer.writeln('  * > 90 dB: Excessive decibel level / potential motor or compressor fault (0% score)');
    buffer.writeln();

    buffer.writeln('### Response Guidelines');
    buffer.writeln('1. When the user asks about one of their registered appliances, refer to their real telemetry readings and status.');
    buffer.writeln('2. Provide clear, actionable advice with numbered or bulleted steps.');
    buffer.writeln('3. Use Markdown formatting: **bold** for key terms, bullet points for lists, and concise summaries.');
    buffer.writeln('4. Emphasize safety whenever electrical or mechanical risks are present (e.g. unplug before inspecting).');
    buffer.writeln('5. Be friendly, knowledgeable, and helpful.');

    return buffer.toString();
  }
}
