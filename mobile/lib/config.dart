/// Build-time configuration. Override with --dart-define=API_BASE_URL=http://HOST:4000
const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:4000');

/// Socket.io shares the API origin.
const String socketUrl = apiBaseUrl;
