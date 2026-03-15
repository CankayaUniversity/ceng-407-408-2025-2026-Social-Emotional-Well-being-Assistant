# ui_prototype

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


## Gemini AI Integration Setup Steps

### 1. Get Gemini API Key
- Go to [Google AI Studio](https://ai.google.dev/)
- Click "Get API key"
- Create a new API key
- Copy your API key

### 2. Use the Gemini API Key

#### Option A: Environment Variables (Recommended for Production)
Run the app using environment variables:

```bash
flutter run --dart-define=GEMINI_API_KEY=your-actual-api-key-here
```

#### Option B: Direct Insertion (Development)
In `lib/core/config/app_config.dart`, replace `YOUR_GEMINI_API_KEY_HERE`:

```dart
static const String geminiApiKey = 'your-actual-api-key-here';
```