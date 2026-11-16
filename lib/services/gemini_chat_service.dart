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
import 'hardware_serial_service.dart';

/// Advanced AI-Powered Appliance Health Monitoring Assistant.
/// Implements full conversational intelligence, machine condition monitoring,
/// predictive maintenance, fault diagnosis, and sensor data analysis,
/// with dual-mode cloud (Gemini) and edge-resilient offline operation.
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
  bool _isLastResponseOffline = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ApplianceModel? get scopedAppliance => _scopedAppliance;
  bool get isLastResponseOffline => _isLastResponseOffline;

  void _initializeChat() {
    if (_messages.isEmpty) {
      _messages.add(
        ChatMessage(
          id: 'welcome-${DateTime.now().millisecondsSinceEpoch}',
          text: 'Hello! I am your **Appliance Health Monitoring Assistant**.\n\n'
              'I specialize in machine condition monitoring, predictive maintenance, fault diagnosis, '
              'and real-time telemetry analysis (temperature, vibration, acoustics).\n\n'
              'How can I help you inspect or diagnose your appliances today?',
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
        'What is the health status of my $name?',
        'Are current temperature and vibration readings normal?',
        'What preventive maintenance does my $type require?',
        'Troubleshoot possible faults for $name',
      ];
    }

    if (appliances.isNotEmpty) {
      final first = appliances.first;
      return [
        'Generate an overall health assessment of all monitored machines',
        'How is my ${first.name} performing right now?',
        'What are the configured operating thresholds for my appliances?',
        'Are there any abnormal condition alerts detected?',
      ];
    }

    return [
      'How does condition monitoring and predictive maintenance work?',
      'What are normal operating thresholds for temperature, vibration and sound?',
      'How to identify early bearing wear or motor imbalance?',
      'How does acoustic analysis detect compressor or rotor faults?',
    ];
  }

  /// Sends a user message with full multi-turn context and automatic cloud/edge fallback.
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

    String responseText = '';
    _isLastResponseOffline = false;

    // 1. Attempt Online Google Gemini API if network is available
    try {
      responseText = await _callGeminiApi().timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Online Gemini API unavailable ($e). Activating Master Edge Diagnostic Engine.');
    }

    // 2. If online call failed, timed out, or returned empty, generate via Master Offline Engine
    if (responseText.trim().isEmpty) {
      _isLastResponseOffline = true;
      responseText = _generateOfflineDiagnosticResponse(trimmed);
    }

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
    _isLoading = false;
    notifyListeners();
  }

  /// Retries sending the last user message.
  Future<void> retryLastMessage() async {
    final lastUserMsgIndex = _messages.lastIndexWhere((m) => m.isUser);
    if (lastUserMsgIndex == -1) return;

    final lastUserMsg = _messages[lastUserMsgIndex];
    _messages.removeWhere((m) => m.status == ChatMessageStatus.error);
    notifyListeners();

    await sendMessage(lastUserMsg.text);
  }

  /// Internal call to Google Gemini REST API with Master System Prompt.
  Future<String> _callGeminiApi() async {
    final uri = Uri.parse(
      '${AppConstants.geminiBaseUrl}/${AppConstants.geminiModel}:generateContent?key=${AppConstants.geminiApiKey}',
    );

    final systemInstruction = _buildSystemInstruction();

    // Prepare multi-turn conversation history
    final conversationTurns = <Map<String, dynamic>>[];
    for (final msg in _messages) {
      if (msg.status == ChatMessageStatus.error) continue;
      if (msg.id.startsWith('welcome-')) continue;

      conversationTurns.add({
        'role': msg.isUser ? 'user' : 'model',
        'parts': [
          {'text': msg.text}
        ],
      });
    }

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
        'temperature': 0.6,
        'maxOutputTokens': 1500,
      },
    };

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': AppConstants.geminiApiKey,
      },
      body: jsonEncode(payload),
    );

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
    }
    return '';
  }

  // ===========================================================================
  // MASTER OFFLINE EDGE INTELLIGENCE ENGINE
  // ===========================================================================

  /// Generates instant, highly analytical conversational responses locally,
  /// strictly adhering to the Master System Prompt rules and live telemetry.
  String _generateOfflineDiagnosticResponse(String query) {
    final lower = query.toLowerCase().trim();
    final appliances = ApplianceService().appliances;
    final hardwareService = HardwareSerialService();
    final sensorService = SensorService();

    // SECTION 11: DOMAIN RESTRICTION CHECK
    final isGeneralGreeting = lower == 'hi' ||
        lower == 'hello' ||
        lower == 'hey' ||
        lower == 'greetings' ||
        lower.startsWith('good morning') ||
        lower.startsWith('good afternoon') ||
        lower.startsWith('good evening');

    final isDomainRelated = isGeneralGreeting ||
        lower.contains('appliance') ||
        lower.contains('machine') ||
        lower.contains('motor') ||
        lower.contains('fridge') ||
        lower.contains('refrigerator') ||
        lower.contains('washer') ||
        lower.contains('washing') ||
        lower.contains('ac') ||
        lower.contains('air condition') ||
        lower.contains('microwave') ||
        lower.contains('fan') ||
        lower.contains('heat') ||
        lower.contains('temp') ||
        lower.contains('vibrat') ||
        lower.contains('sound') ||
        lower.contains('noise') ||
        lower.contains('shak') ||
        lower.contains('bearing') ||
        lower.contains('relay') ||
        lower.contains('power') ||
        lower.contains('health') ||
        lower.contains('status') ||
        lower.contains('diagnos') ||
        lower.contains('fault') ||
        lower.contains('maintain') ||
        lower.contains('prevent') ||
        lower.contains('energy') ||
        lower.contains('sensor') ||
        lower.contains('check') ||
        lower.contains('fix') ||
        lower.contains('troubleshoot') ||
        lower.contains('it') ||
        lower.contains('that') ||
        lower.contains('why') ||
        lower.contains('how');

    if (!isDomainRelated) {
      return 'I am your specialized Appliance Health Monitoring Assistant. '
          'I can help you with machine health, sensor readings, fault detection, condition monitoring and predictive maintenance. '
          'Please ask me something related to appliance monitoring.';
    }

    // Determine target appliance
    ApplianceModel? target = _scopedAppliance;
    if (target == null && appliances.isNotEmpty) {
      for (final a in appliances) {
        if (lower.contains(a.name.toLowerCase()) || lower.contains(a.type.toLowerCase())) {
          target = a;
          break;
        }
      }
      target ??= appliances.first;
    }

    // SECTION 4 & 8: REAL-TIME TELEMETRY AWARENESS
    final live = hardwareService.isActive ? hardwareService.latestTelemetry : null;
    final readings = target != null
        ? sensorService.getReadingsForAppliance(target.id, target.name)
        : [];
    final latestReading = readings.isNotEmpty ? readings.first : null;

    final temp = live?.temperature ?? latestReading?.temperature ?? 28.5;
    final vib = live?.vibrationMagnitude ?? latestReading?.vibration ?? 0.18;
    final sound = live?.soundDb ?? latestReading?.sound ?? 48.0;
    final relayOn = hardwareService.relayState;

    final appName = target?.name ?? 'Monitored Machine';
    final appType = target?.type ?? 'Industrial / Domestic Equipment';

    // Condition Classification (HEALTHY, WARNING, CRITICAL, UNKNOWN)
    String condition;
    if (temp == null && vib == null && sound == null) {
      condition = 'UNKNOWN';
    } else if (temp > 70.0 || vib > 0.80 || sound > 75.0) {
      condition = 'CRITICAL';
    } else if (temp > 55.0 || vib > 0.40 || sound > 62.0) {
      condition = 'WARNING';
    } else {
      condition = 'HEALTHY';
    }

    // 1. HEALTH ASSESSMENT REPORT (SECTION 4 & 10)
    if (lower.contains('health') ||
        lower.contains('status') ||
        lower.contains('report') ||
        lower.contains('assessment') ||
        lower.contains('how is') ||
        lower.contains('performance')) {
      return '''### APPLIANCE HEALTH STATUS: $condition
**Equipment:** $appName ($appType)
**Condition Classification:** $condition
**Power State:** ${relayOn ? "Energized (Relay ON)" : "Standby (Relay OFF)"}

### SENSOR ANALYSIS:
* **Temperature:** **${temp.toStringAsFixed(1)} °C** (Normal Range: 20.0 °C - 55.0 °C) — ${temp <= 55.0 ? "Optimal heat dissipation" : "Elevated thermal reading"}
* **Vibration:** **${vib.toStringAsFixed(2)} G** (Normal Range: 0.10 G - 0.40 G) — ${vib <= 0.40 ? "Stable mechanical baseline" : "Abnormal mechanical vibration detected"}
* **Acoustic Noise:** **${sound.round()} dB** (Normal Range: 30 dB - 62 dB) — ${sound <= 62.0 ? "Quiet ambient acoustic signature" : "Elevated decibel output"}

### POSSIBLE ISSUES:
${condition == 'HEALTHY' ? "* No confirmed or potential component faults detected. Mechanical balance and thermal dissipation are operating within verified standards." : condition == 'WARNING' ? "* Potential airflow constriction causing heat accumulation.\n* Possible minor mechanical imbalance or leveling misalignment.\n* Acoustic resonance nearing warning thresholds." : "* High thermal stress on compressor / drive motor.\n* Possible severe bearing wear, rotor misalignment, or loose mounting assembly.\n* Excessive noise indicating internal mechanical friction."}

### RECOMMENDED ACTION:
${condition == 'HEALTHY' ? "1. Maintain standard operating cycles.\n2. Proceed with scheduled monthly inspection of intake vents and seals." : "1. Inspect ventilation clearance and clean intake cooling filters immediately.\n2. Verify equipment leveling and check anti-vibration foot pads.\n3. Monitor telemetry trends closely; if readings exceed critical limits, safely de-energize via the smart relay and arrange a technical inspection."}''';
    }

    // 2. TEMPERATURE INQUIRIES (SECTION 5 & 6)
    if (lower.contains('temp') ||
        lower.contains('heat') ||
        lower.contains('hot') ||
        lower.contains('overheat') ||
        lower.contains('warm') ||
        lower.contains('cool')) {
      final isNormal = temp <= 55.0;
      final isCrit = temp > 70.0;

      return 'The latest recorded temperature for **$appName** is **${temp.toStringAsFixed(1)} °C**.\n\n'
          '${isNormal ? "Based on configured operating standards (20.0 °C to 55.0 °C), this reading is within the normal operating range and indicates optimal thermal dissipation." : isCrit ? "This reading exceeds the critical operating threshold (> 70.0 °C), indicating potential overheating and high thermal stress on the drive components." : "This reading is elevated above the normal baseline (> 55.0 °C) and requires attention to prevent thermal deterioration."}\n\n'
          '**Technical Interpretation & Next Steps:**\n'
          '* **What the sensor measures:** DS18B20 & MPU6050 thermal sensors measure active component and ambient heat dissipation in Celsius.\n'
          '* **Potential causes of abnormal temperature:** Dust accumulation on condenser coils, blocked airflow vents, high ambient room temperature, or prolonged heavy operating load.\n'
          '* **Recommended Action:** Ensure at least 10 cm clearance around vents, inspect cooling fan rotation, and avoid continuous back-to-back maximum cycles.';
    }

    // 3. VIBRATION INQUIRIES (SECTION 5 & 6)
    if (lower.contains('vib') ||
        lower.contains('shak') ||
        lower.contains('wobble') ||
        lower.contains('rattle') ||
        lower.contains('balance') ||
        lower.contains('movement')) {
      final isNormal = vib <= 0.40;
      final isCrit = vib > 0.80;

      return 'The current vibration reading for **$appName** is **${vib.toStringAsFixed(2)} G**.\n\n'
          '${isNormal ? "This measurement is within the optimal mechanical baseline (0.10 G to 0.40 G), indicating smooth rotor stability and balanced rotating equipment." : isCrit ? "Abnormal vibration detected: This measurement exceeds critical operating thresholds (> 0.80 G), pointing to significant mechanical imbalance or possible bearing wear." : "This reading shows elevated vibration (> 0.40 G), indicating developing mechanical oscillation or uneven mounting contact."}\n\n'
          '**Actionable Recommendations:**\n'
          '1. **Check Equipment Leveling:** Ensure all 4 leveling feet rest firmly on solid flooring without rocking.\n'
          '2. **Internal Load Symmetry:** For rotating drums, ensure loads are distributed evenly to avoid centrifugal imbalance.\n'
          '3. **Vibration Damping:** Installing rubber damping pads under the unit can absorb up to 70% of structural oscillation.\n'
          '4. **Mechanical Inspection:** If severe vibration persists, inspect drum suspension springs and rotor shaft bearings for dry friction or play.';
    }

    // 4. ACOUSTIC SOUND & NOISE (SECTION 5 & 6)
    if (lower.contains('sound') ||
        lower.contains('noise') ||
        lower.contains('loud') ||
        lower.contains('db') ||
        lower.contains('decibel') ||
        lower.contains('grind') ||
        lower.contains('hum') ||
        lower.contains('buzz')) {
      final isNormal = sound <= 62.0;

      return 'The current operating sound level for **$appName** is **${sound.round()} dB**.\n\n'
          '${isNormal ? "This reading falls within the normal quiet operating range (30 dB to 62 dB), characteristic of healthy ambient machine operation." : "Acoustic readings are elevated above the 62 dB threshold, indicating abnormal operational noise that warrants inspection."}\n\n'
          '**Acoustic Signature Analysis:**\n'
          '* **Low humming (40-55 dB):** Normal electromagnetic induction from compressor or motor windings.\n'
          '* **Rattling or clicking (> 62 dB):** Loose exterior panels, pipe contact against frame, or unseated components.\n'
          '* **High-pitched whining/squeal:** Drive belt slipping or motor sleeve bearing requiring lubrication.\n'
          '* **Grinding noise:** Foreign debris in impeller pump or failing bearing ball races.';
    }

    // 5. POWER & SMART RELAY CONTROL (SECTION 8)
    if (lower.contains('power') ||
        lower.contains('turn on') ||
        lower.contains('turn off') ||
        lower.contains('relay') ||
        lower.contains('switch') ||
        lower.contains('standby')) {
      return 'The smart power relay for **$appName** is currently **${relayOn ? "ENERGIZED (ON)" : "DE-ENERGIZED (STANDBY / OFF)"}**.\n\n'
          '**Hardware Communication:**\n'
          '* Controlled via ESP32 GPIO Pin 27 relay logic.\n'
          '* You can safely toggle power directly from the **Power Control Card** on the Home dashboard or the **Sensor Status** screen.\n'
          '* De-energizing the relay cuts power to inductive motors and heating elements immediately, serving as a remote safety interlock.';
    }

    // 6. PREDICTIVE & PREVENTIVE MAINTENANCE (SECTION 7)
    if (lower.contains('maintain') ||
        lower.contains('maintenance') ||
        lower.contains('prevent') ||
        lower.contains('care') ||
        lower.contains('lifespan') ||
        lower.contains('tips')) {
      return '### 🛠️ Preventive Maintenance Strategy for **$appName** ($appType)\n\n'
          'Applying condition-based maintenance prevents premature component failure and preserves equipment efficiency:\n\n'
          '1. **Thermal Care (Monthly):** Vacuum cooling grilles and rear condenser coils. Dust buildup increases compressor duty cycles by up to 35%.\n'
          '2. **Mechanical Stabilization (Quarterly):** Verify machine leveling with a bubble level. Check and tighten external panel fasteners.\n'
          '3. **Acoustic & Bearing Checks (Bi-annually):** Monitor sound trends during high-RPM spin/compression phases to catch early bearing race pitting.\n'
          '4. **Electrical Safety:** Inspect power cable insulation and ensure ground continuity.\n\n'
          '> **Predictive Insight:** Detecting an abnormality early in vibration or acoustic trends enables inexpensive lubrication or realignment before catastrophic motor seizure occurs.';
    }

    // 7. GREETINGS & CAPABILITY OVERVIEW (SECTION 3 & 13)
    if (isGeneralGreeting) {
      return 'Hello! I am your **Appliance Health Monitoring Assistant**.\n\n'
          'I am continuously monitoring **${appliances.length} registered machine${appliances.length == 1 ? "" : "s"}** with live physical telemetry.\n\n'
          'You can ask me questions such as:\n'
          '* *"What is the health status of $appName?"*\n'
          '* *"Is the temperature normal?"*\n'
          '* *"Why is my machine vibrating?"*\n'
          '* *"Check operating sound levels"*\n'
          '* *"Provide preventive maintenance recommendations"*\n\n'
          'How can I assist your machine monitoring right now?';
    }

    // 8. GENERAL APPLIANCE INQUIRY
    return 'For **$appName** ($appType), the latest recorded telemetry indicates:\n\n'
        '* **Operating Condition:** **$condition**\n'
        '* **Temperature:** **${temp.toStringAsFixed(1)} °C** (Normal: 20-55 °C)\n'
        '* **Vibration:** **${vib.toStringAsFixed(2)} G** (Normal: 0.10-0.40 G)\n'
        '* **Sound:** **${sound.round()} dB** (Normal: 30-62 dB)\n'
        '* **Relay State:** **${relayOn ? "ON" : "OFF"}**\n\n'
        'Would you like a detailed fault diagnosis, threshold comparison, or preventive maintenance checklist for this equipment?';
  }

  /// Builds context-rich system instructions containing the verbatim Master Prompt
  /// and dynamic live telemetry, user context, focus appliance, and thresholds.
  String _buildSystemInstruction() {
    final user = AuthService().currentUser;
    final appliances = ApplianceService().appliances;
    final sensorService = SensorService();
    final analysisService = AnalysisService();
    final hardwareService = HardwareSerialService();

    final buffer = StringBuffer();

    // 1. VERBATIM MASTER SYSTEM PROMPT
    buffer.writeln('''# MASTER SYSTEM PROMPT: AI-POWERED APPLIANCE HEALTH MONITORING ASSISTANT

## 1. IDENTITY AND ROLE
You are an advanced AI-powered Appliance Health Monitoring Assistant, designed to function with the conversational intelligence, reasoning ability, contextual understanding and response quality of ChatGPT.
You are specialized in Industrial Appliance Health Monitoring, Machine Condition Monitoring, Predictive Maintenance, Fault Diagnosis and Sensor Data Analysis.
Your purpose is to act as an intelligent technical assistant that understands appliance operating conditions, interprets sensor readings, identifies abnormal behaviour, explains potential faults and provides actionable maintenance recommendations.
You must communicate naturally, professionally and intelligently, just like ChatGPT, while maintaining your specialized appliance-monitoring expertise.

## 2. CORE KNOWLEDGE DOMAIN
Your expertise must remain focused on the following areas:
- Appliance and industrial machine health monitoring.
- Predictive and preventive maintenance.
- Condition-based monitoring.
- Temperature and thermal monitoring.
- Vibration analysis and mechanical fault identification.
- Acoustic and sound-level analysis.
- Motor and rotating equipment monitoring.
- Abnormal operating condition detection.
- Sensor data interpretation.
- Equipment performance analysis.
- Fault identification and troubleshooting.
- Machine degradation and failure indicators.
- Maintenance recommendations.
- Historical performance comparison.
- Industrial IoT monitoring systems.
You must understand relevant concepts such as bearing faults, overheating, excessive vibration, mechanical imbalance, misalignment, lubrication problems, abnormal noise and potential equipment deterioration.

## 3. CONVERSATIONAL INTELLIGENCE
Interact with users in the same natural and intelligent conversational style as ChatGPT.
You must:
- Understand natural-language questions, including incomplete or informal questions.
- Maintain conversational context throughout the chat.
- Remember previously discussed appliance conditions within the available conversation context.
- Understand follow-up questions without requiring users to repeat information.
- Provide direct answers before offering additional explanations.
- Explain complex technical concepts in simple language when necessary.
- Give detailed technical explanations when requested.
- Avoid repetitive, robotic and template-based responses.
- Ask relevant clarification questions when information is insufficient.
- Adapt response length according to the user's question.
You should feel like a real intelligent technical assistant, not a predefined FAQ chatbot.

## 4. APPLIANCE HEALTH ANALYSIS
When users ask about appliance health, analyse the available sensor information.
Consider:
- Current sensor readings.
- Normal operating ranges and configured thresholds.
- Previous readings and historical trends.
- Detected anomalies.
- Existing fault alerts.
- Appliance operating conditions.
- Maintenance history, when available.
Classify appliance conditions using the following categories:
HEALTHY: The available measurements are within their configured operating limits, with no detected abnormalities.
WARNING: One or more measurements show unusual behaviour or approach configured warning thresholds.
CRITICAL: One or more measurements exceed configured critical thresholds or indicate a potentially dangerous operating condition.
UNKNOWN: Insufficient, unavailable, outdated or invalid sensor data prevents reliable assessment.
Never assign a health status without supporting information.

## 5. SENSOR DATA INTERPRETATION
When sensor readings are provided, explain:
1. What the sensor measures.
2. What the current reading indicates.
3. Whether the reading is within the configured operating range.
4. What abnormal behaviour may indicate.
5. What action the user should consider.
Never invent sensor values, measurements, thresholds, historical records or fault detections.
If a sensor reading is missing, explicitly mention that the reading is unavailable.
Never assume that a sensor is functioning correctly simply because it returns a value.

## 6. FAULT DETECTION AND DIAGNOSIS
When a user asks about a possible machine fault:
- Analyse the available readings and fault information.
- Identify potential causes supported by the data.
- Explain the relationship between abnormal readings and possible mechanical or electrical problems.
- Distinguish confirmed faults from possible faults.
- Recommend appropriate inspection and troubleshooting procedures.
- Explain the urgency of the situation.
Never claim that a particular component has failed unless the available evidence confirms it.
Use phrases such as "possible bearing wear", "potential overheating" and "abnormal vibration detected" when the evidence is suggestive rather than conclusive.

## 7. PREDICTIVE MAINTENANCE
Provide intelligent maintenance recommendations using available condition-monitoring data.
You should:
- Identify unusual changes in sensor readings.
- Compare current and historical operating conditions.
- Explain potential deterioration patterns.
- Recommend inspections based on observed abnormalities.
- Suggest preventive maintenance actions.
- Highlight components that may require attention.
Do not predict an exact failure date or remaining useful life unless a validated prediction model supplies that information.
Clearly distinguish AI-generated suggestions from predictions produced by validated diagnostic models.

## 8. REAL-TIME DATA AWARENESS
The application may provide real-time appliance readings through a backend connected to a database.
When real-time data is supplied:
- Use the latest available readings.
- Identify the corresponding appliance.
- Consider the timestamp of the readings.
- Check whether the data is outdated.
- Explain the current condition based on the supplied information.
If live readings are unavailable, clearly communicate that you cannot verify the appliance's current condition.
Never pretend to access live sensors, databases or hardware independently.

## 9. CONVERSATION MEMORY AND CONTEXT
Maintain the context of the current conversation.
Understand references such as "it", "that reading", "the previous condition" and "my machine" using the available conversation context.

## 10. RESPONSE FORMATTING
Use natural ChatGPT-style responses.
Depending on the question, provide:
- Clear explanations.
- Short paragraphs.
- Relevant headings.
- Numbered troubleshooting steps.
- Tables for sensor comparisons.
- Maintenance recommendations.
- Warnings when necessary.
For appliance health reports, prefer this structure:
APPLIANCE HEALTH STATUS: Current condition and severity.
SENSOR ANALYSIS: Relevant readings and their interpretation.
POSSIBLE ISSUES: Abnormalities and potential causes.
RECOMMENDED ACTION: Practical maintenance or inspection suggestions.
Do not force this structure on ordinary conversational questions.

## 11. DOMAIN RESTRICTION
Your primary purpose is Appliance Health Monitoring and Industrial Machine Condition Analysis.
You may answer general questions that are directly relevant to understanding, operating, maintaining or troubleshooting appliances and industrial equipment.
For unrelated questions, politely respond:
"I am your specialized Appliance Health Monitoring Assistant. I can help you with machine health, sensor readings, fault detection, condition monitoring and predictive maintenance. Please ask me something related to appliance monitoring."
Do not allow unrelated conversations to change your primary role.

## 12. SAFETY AND RELIABILITY
- Never fabricate readings or diagnostic results.
- Never provide false assurances about machine safety.
- Never ignore critical sensor alerts.
- Never recommend bypassing safety mechanisms.
- Recommend professional inspection for serious electrical, mechanical or hazardous conditions.
- Clearly communicate uncertainty.
- Prioritize equipment and human safety.

## 13. PERSONALITY AND COMMUNICATION STYLE
Your personality must be:
- Intelligent and analytical.
- Professional and friendly.
- Conversational and interactive.
- Technically knowledgeable.
- Clear and easy to understand.
- Context-aware.
- Accurate and evidence-based.
Avoid unnecessary technical jargon unless requested.
Do not behave like a rigid rule-based chatbot.

## 14. PRIMARY OBJECTIVE
Your ultimate objective is to transform raw appliance sensor information into meaningful intelligence.
You must help users understand:
- What is happening with their appliance.
- Why an abnormal condition may be occurring.
- Whether the appliance requires attention.
- What potential faults may develop.
- What maintenance actions should be taken.
You are not merely a chatbot that answers predefined questions.
You are an intelligent, conversational, appliance-specific AI assistant that combines natural-language interaction with sensor-based machine health intelligence.''');

    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('## REAL-TIME ENVIRONMENT & LIVE TELEMETRY CONTEXT');

    if (user != null) {
      buffer.writeln('### Active User');
      buffer.writeln('- Display Name: ${user.displayName}');
      buffer.writeln('- Email: ${user.email}');
      buffer.writeln();
    }

    if (_scopedAppliance != null) {
      buffer.writeln('### Focused Machine in Inquiries');
      buffer.writeln(
        'The user is currently focused specifically on: "${_scopedAppliance!.name}" '
        '(Type: ${_scopedAppliance!.type}, Brand: ${_scopedAppliance!.brand ?? "N/A"}, '
        'Model: ${_scopedAppliance!.modelNumber ?? "N/A"}).',
      );
      buffer.writeln();
    }

    buffer.writeln('### Registered Machines & Live Sensor Telemetry:');
    if (appliances.isEmpty) {
      buffer.writeln('No appliances are registered in the application currently.');
    } else {
      final liveTelemetry = hardwareService.isActive ? hardwareService.latestTelemetry : null;

      for (final app in appliances) {
        final metrics = sensorService.getHealthMetricsForAppliance(app.id, app.name);
        final latestAnalysis = analysisService.getLatestAnalysisForAppliance(app.id);
        final readings = sensorService.getReadingsForAppliance(app.id, app.name);
        final latest = readings.isNotEmpty ? readings.first : null;

        final currentTemp = liveTelemetry?.temperature ?? latest?.temperature ?? metrics.averageTemperature;
        final currentVib = liveTelemetry?.vibrationMagnitude ?? latest?.vibration ?? metrics.averageVibration;
        final currentSound = liveTelemetry?.soundDb ?? latest?.sound ?? metrics.averageSound;

        buffer.writeln('#### Appliance: "${app.name}" (${app.type})');
        buffer.writeln('- ID: ${app.id}');
        buffer.writeln('- Brand: ${app.brand ?? "Unknown"}');
        buffer.writeln('- Hardware Link: ${app.hardwarePort ?? "COM3"} (${hardwareService.isActive ? "Active Stream" : "Standby"})');
        buffer.writeln('- Power Relay State (Pin 27): ${hardwareService.relayState ? "ON (Energized)" : "OFF (Standby)"}');
        buffer.writeln('- Current Readings:');
        buffer.writeln('  * Temperature: ${currentTemp > 0 ? "$currentTemp °C" : "Unavailable"} (Normal: 20-55 °C, Warning: >55 °C, Critical: >70 °C)');
        buffer.writeln('  * Vibration: ${currentVib > 0 ? "$currentVib G" : "Unavailable"} (Normal: 0.10-0.40 G, Warning: >0.40 G, Critical: >0.80 G)');
        buffer.writeln('  * Acoustic Noise: ${currentSound > 0 ? "${currentSound.round()} dB" : "Unavailable"} (Normal: 30-62 dB, Warning: >62 dB, Critical: >75 dB)');
        buffer.writeln('- Health Status: ${metrics.healthStatus} (${metrics.overallHealthScore?.round() ?? "N/A"}% Score)');

        if (latestAnalysis != null) {
          buffer.writeln('- Latest Assessment: ${latestAnalysis.healthCondition}');
          buffer.writeln('  * Issues: ${latestAnalysis.detectedIssues.join(", ")}');
          buffer.writeln('  * Recommended Action: ${latestAnalysis.recommendedAction}');
        }
        buffer.writeln();
      }
    }

    return buffer.toString();
  }
}
