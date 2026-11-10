# MyAppliance 🔌📱
> **Smart Appliance Health Checker & AI Diagnostic Assistant**

MyAppliance is a modern Flutter application built to monitor, diagnose, and maintain household appliances with real-time sensor telemetry, guided health checkups, and a context-aware **Google Gemini AI Appliance Assistant**.

---

## 🌟 Key Features

### 1. 🤖 Context-Aware Gemini AI Appliance Assistant
- **Powered by Google Gemini 3.8 Flash**: Direct integration with Google's Generative AI API for lightning-fast, expert-level appliance troubleshooting and advice.
- **Dynamic Context Injection**: The AI Assistant automatically receives real-time context about:
  - Your registered appliances (brand, model number, purchase date, type).
  - Live sensor telemetry (average temperature, vibration, decibel sound readings).
  - Diagnostic scan results and detected issues.
  - Appliance health benchmarks and safety thresholds.
- **Appliance Scope Selector**: Easily toggle between queries for **All Appliances** or focus specifically on a single device (e.g., your Samsung Refrigerator or Daikin AC).
- **Interactive Multi-Turn Dialogue**: Natural, continuous conversations with full memory of previous turns.
- **Quick Suggested Prompts**: Dynamic chips suggested based on the appliances you own for instant 1-tap inquiries.
- **Rich Markdown Formatting**: Clear headers, bullet lists, bold highlights, safety precautions, and one-tap copy to clipboard.
- **Accessible Everywhere**:
  - In-screen **Ask AI** Floating Action Button & Header Shortcut on the Home dashboard (opens an interactive slide-up AI assistant sheet directly on the screen).
  - Quick-access action buttons in **Appliance Details**.
  - Direct entry from **Settings**.
  - Dedicated route `/chatbot` for full-screen mode.

### 2. 📊 Real-Time Sensor Telemetry & Health Scoring
- Tracks crucial operational metrics:
  - **Temperature (°C)**: Overheating detection.
  - **Vibration (G / m/s²)**: Mechanical imbalance, loose bearings, or uneven mounting.
  - **Sound Level (dB)**: Motor strain, compressor grinding, or fan friction.
- Normalized score computation ($0 - 100\%$) and automatic status assignment:
  - 🟢 **Good**: Score $\ge 80\%$
  - 🟡 **Average**: Score between $60\% - 79\%$
  - 🔴 **Poor**: Score $< 60\%$

### 3. 🔍 Guided Health Checks & Diagnostic Scans
- Tailored question trees for each appliance category (Refrigerator, Washing Machine, Air Conditioner, Microwave, Television, Fan).
- Generates targeted recommendations, maintenance checklists, and risk assessments.
- Stores historical analysis records.

### 4. 🗄️ Supabase Cloud Backend
- User authentication and persistent profile storage.
- Real-time appliance synchronization.
- Historical telemetry logs and diagnostic records.

---

## 📏 Sensor Health Benchmarks & Standards

| Metric | Optimal / Healthy (100%) | Warning Range | Critical Hazard (0%) |
| :--- | :--- | :--- | :--- |
| **Temperature** | $20^\circ\text{C} - 60^\circ\text{C}$ | $60^\circ\text{C} - 80^\circ\text{C}$ (Score drops) | $> 80^\circ\text{C}$ (Overheating risk) |
| **Vibration** | $0.10 - 0.40$ | $0.40 - 1.00$ (Elevated vibration) | $> 1.00$ (Severe mechanical imbalance) |
| **Sound Level** | $30 - 60\text{ dB}$ | $60 - 90\text{ dB}$ (Noticeable noise) | $> 90\text{ dB}$ (Hearing hazard / motor failure) |

---

## 🛠️ Project Architecture

```
myappliance/
├── lib/
│   ├── app/
│   │   ├── app.dart                    # Main MaterialApp setup
│   │   ├── routes.dart                 # App navigation route generator (/chatbot, /home, etc.)
│   │   └── theme.dart                  # Material3 theme & visual styles
│   ├── data/
│   │   └── appliance_health_questions.dart # Diagnostic questionnaires repository
│   ├── models/
│   │   ├── analysis_model.dart         # Diagnostic analysis model
│   │   ├── appliance_health_metrics.dart # Health scores & telemetry metrics
│   │   ├── appliance_model.dart        # Appliance data entity
│   │   ├── chat_message_model.dart     # AI Chatbot message & status model
│   │   ├── health_option.dart          # Diagnostic option entity
│   │   ├── health_question.dart        # Diagnostic question entity
│   │   ├── health_result.dart          # Evaluated questionnaire result
│   │   ├── sensor_reading_model.dart   # Telemetry reading entry
│   │   └── user_model.dart             # User profile entity
│   ├── screens/
│   │   ├── analytics/                  # Telemetry analytics screen
│   │   ├── auth/                       # Login, Register & Profile Setup
│   │   ├── chat/
│   │   │   └── chatbot_screen.dart     # Interactive Gemini AI Chatbot Screen
│   │   ├── home/                       # Home Dashboard, Appliance Details, Health Check
│   │   ├── results/                    # Diagnostic results log
│   │   ├── settings/                   # App & User settings
│   │   ├── splash/                     # Animated splash screen
│   │   └── main_layout.dart            # 4-tab container with Global AI FAB
│   ├── services/
│   │   ├── analysis_service.dart       # Diagnostic scan engine
│   │   ├── appliance_service.dart      # Appliance CRUD with Supabase
│   │   ├── auth_service.dart           # Supabase Auth management
│   │   ├── gemini_chat_service.dart    # Gemini 3.8 Flash AI conversation engine
│   │   ├── health_check_service.dart   # Health check calculation logic
│   │   └── sensor_service.dart         # Sensor telemetry fetch & aggregation
│   ├── utils/
│   │   ├── app_colors.dart             # Centralized design system color palette
│   │   ├── app_text_styles.dart        # Typography definitions
│   │   └── constants.dart              # Supabase & Gemini API configuration
│   └── widgets/
│       ├── appliance_card.dart         # Appliance list item card
│       ├── bottom_navigation.dart      # Custom bottom navigation bar
│       ├── chat_markdown_view.dart     # Rich Markdown parser for AI messages
│       ├── custom_text_field.dart      # Styled input fields
│       ├── empty_state.dart            # Reusable empty state view
│       └── primary_button.dart         # Reusable primary button
├── test/
│   ├── chatbot_test.dart               # Unit & Widget tests for AI Chatbot
│   └── widget_test.dart                # Splash screen smoke test
└── pubspec.yaml
```

---

## ⚙️ Configuration & Setup

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (`v3.12+` or `v3.44+`)
- [Dart SDK](https://dart.dev/get-dart) (`^3.12.2`)

### 1. Clone & Install Dependencies
```bash
git clone <repository-url>
cd myappliance
flutter pub get
```

### 2. Configure API Keys
The API credentials are central in `lib/utils/constants.dart`:

```dart
class AppConstants {
  static const String appName = 'MyAppliance';
  static const String appSubtitle = 'Appliance Health Checker';

  // Supabase Configuration
  static const String supabaseUrl = 'https://jalicryunnjxmipuihwp.supabase.co';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  // Google Gemini AI Configuration
  static const String geminiApiKey = 'YOUR_GEMINI_API_KEY';
  static const String geminiModel = 'gemini-3.8-flash';
  static const String geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';
}
```

### 3. Run the Application
```bash
# Run on connected device or emulator:
flutter run

# Run on Windows:
flutter run -d windows

# Run on Web:
flutter run -d chrome
```

### 4. Run Automated Tests
```bash
flutter test
```
All unit and widget tests covering models, routes, services, and chat widgets are located in the `test/` directory.

---

## 💬 How the AI Chatbot Works

1. **Context Ingestion**: When the user asks a question, `GeminiChatService` builds a comprehensive prompt containing:
   - The user's registered appliances with their brand and model specifications.
   - Latest sensor readings (average temperature, vibration level, sound level, and calculated health score).
   - Any prior diagnostic issues identified.
   - Standard engineering health limits for household appliances.
2. **Context Focusing**: When accessed from an individual appliance screen or when selected in the top filter bar, the AI prioritizes that appliance in its recommendations while remaining knowledgeable about the user's entire home.
3. **Execution**: The message history and system instruction are sent to Google's Gemini 3.8 Flash endpoint.
4. **Rendering**: The response is parsed with `ChatMarkdownView` into an elegant, styled presentation with copy-to-clipboard functionality and suggested follow-up queries.

---

## 📄 License
This project is licensed under the MIT License.
