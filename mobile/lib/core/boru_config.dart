class BoruConfig {
  static const livekitUrl = String.fromEnvironment('LIVEKIT_URL', defaultValue: 'wss://boru-ghy3t04q.livekit.cloud');
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
}
