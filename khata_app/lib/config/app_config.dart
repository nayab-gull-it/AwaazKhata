/// Central configuration values for AwaazKhata.
///
/// All environment-specific values (backend URL, timeouts, feature flags)
/// live here so the rest of the codebase stays environment-agnostic.
///
/// IMPORTANT: This file is structured to be excluded from version control.
/// In production, load sensitive values from environment variables,
/// `--dart-define` compile-time variables, or a secret manager instead of
/// checking them into git.
class AppConfig {
  const AppConfig._();

  /// Base URL of the AwaazKhata backend.
  ///
  /// The Flutter app never calls Qwen or any other AI service directly;
  /// all AI processing happens on this backend.
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// Default timeout for network requests to the backend.
  static const Duration backendTimeout = Duration(seconds: 30);

  /// Locale used for Urdu voice commands and formatted dates/numbers.
  // TEMP: switched to en_US to diagnose recognition accuracy; revert to
  // ur_PK once testing is done.
  static const String appLocale = 'en_US';
}
