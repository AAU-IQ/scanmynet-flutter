/// Build-time credentials for the ScanMyNet backend.
///
/// The backend/frontend hosts are environment-specific — see [AppEnvironment].
/// Only the secret API key is supplied via --dart-define so nothing sensitive is
/// committed:
///   flutter run --dart-define=SMN_API_KEY=xxxx
class ScanCredentials {
  const ScanCredentials._();

  /// Authorization key for the backend. Never commit a real value.
  ///
  /// Note: this single key targets the dev backend. Staging/production may
  /// require their own keys — pass the right one per build via --dart-define.
  static const apiKey =
      String.fromEnvironment('SMN_API_KEY', defaultValue: 'YOUR_API_KEY');

  /// Display name for the host app (sent as the report's `app` field).
  static const appName = 'SMN';
}
