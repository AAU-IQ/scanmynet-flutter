/// The ScanMyNet deployments the demo can target.
///
/// Each environment pairs a **backend** host (where scans are submitted) with a
/// **frontend** host (the dashboard used to build shareable report links).
enum AppEnvironment { dev, staging, production }

/// Default environment selected on launch.
const AppEnvironment kDefaultEnvironment = AppEnvironment.dev;

extension AppEnvironmentConfig on AppEnvironment {
  /// Short label for the environment selector.
  String get label => switch (this) {
        AppEnvironment.dev => 'Dev',
        AppEnvironment.staging => 'Staging',
        AppEnvironment.production => 'Prod',
      };

  /// Backend host. The SDK's Retrofit endpoints already include the `api/v1/`
  /// path (e.g. POST api/v1/report/), so this is the host ONLY, trailing `/`.
  String get backendBaseUrl => switch (this) {
        AppEnvironment.dev =>
          'https://scanmynet-backend.dev.kvm.creativeadvtech.ml/',
        AppEnvironment.staging =>
          'https://scanmynet-backend.stg.kvm.creativeadvtech.ml/',
        // EarthLink production backend.
        AppEnvironment.production => 'https://scanmynet.earthlink.iq/',
      };

  /// Dashboard host used to build report links (trailing `/`).
  String get frontendBaseUrl => switch (this) {
        AppEnvironment.dev => 'https://scanmynet.dev.kvm.creativeadvtech.ml/',
        AppEnvironment.staging =>
          'https://scanmynet.stg.kvm.creativeadvtech.ml/',
        // TODO(prod): the native app's production flavor defines no FRONTEND_URL,
        // so the production dashboard host is unconfirmed. Placeholder only.
        AppEnvironment.production => 'https://smn.creativeadvtech.ml/',
      };

  /// Production isn't wired with a confirmed dashboard URL yet — surfaced in the
  /// UI so the report link isn't trusted blindly.
  bool get isPlaceholder => this == AppEnvironment.production;
}
