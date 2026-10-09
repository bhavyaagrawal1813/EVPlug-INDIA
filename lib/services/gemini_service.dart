import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class GeminiService {
  static const String _model = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-2.5-flash',
  );

  static String get _endpoint =>
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_model:generateContent';

  static const String disabledMessage =
      'EV AI is temporarily unavailable. '
      'The rest of EVPlug works without it.';

  static bool _initialized = false;

  static bool get isEnabled =>
      Config.aiEnabled && Config.geminiApiKey.isNotEmpty;

  static void initialize() {
    if (_initialized) return;
    _initialized = true;
    if (!Config.aiEnabled) {
      debugPrint('GeminiService: AI feature disabled for this build.');
      return;
    }
    if (Config.geminiApiKey.isEmpty) {
      debugPrint(
        'GeminiService: GEMINI_API_KEY is empty. '
        'Pass --dart-define=GEMINI_API_KEY=... when running the app.',
      );
    }
  }

  static Future<String> generateResponse(String prompt) async {
    // Never call the AI API unless the feature is explicitly enabled.
    if (!isEnabled) {
      debugPrint('GeminiService: request skipped, AI feature disabled.');
      return disabledMessage;
    }

    try {

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': Config.geminiApiKey,
        },
        body: jsonEncode({
          "contents": [
            {
              "role": "user",
              "parts": [
                {"text": prompt},
              ],
            },
          ],
        }),
      );

      if (response.statusCode != 200) {
        return "API Error (${response.statusCode})\n${response.body}";
      }

      final data = jsonDecode(response.body);

      final candidates = data["candidates"];
      if (candidates is List && candidates.isNotEmpty) {
        final content = candidates.first["content"];
        final parts = content is Map ? content["parts"] : null;
        if (parts is List && parts.isNotEmpty) {
          final text = parts.first["text"];
          if (text is String && text.isNotEmpty) {
            return text;
          }
        }
      }

      return "Unexpected response:\n${response.body}";
    } catch (e) {
      return "Error: $e";
    }
  }
}