class Config {
static const String googleApiKey = String.fromEnvironment(
'GOOGLE_API_KEY',
defaultValue: '',
);

static const String geminiApiKey = String.fromEnvironment(
'GEMINI_API_KEY',
defaultValue: '',
);

static const bool aiEnabled = bool.fromEnvironment(
'AI_ENABLED',
defaultValue: false,
);
}
