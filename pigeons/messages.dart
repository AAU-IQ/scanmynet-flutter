// Pigeon schema for the ScanMyNet Flutter plugin.
//
// This file defines the type-safe platform-channel contract between Dart and
// the native RouteThis ScanMyNet SDKs (Android `tools` module / iOS ScanMyNet).
//
//   Dart  -> Native : @HostApi  ScanHostApi   (configure / startScan / cancel)
//   Native -> Dart  : @FlutterApi ScanFlutterApi (started/progress/finished/
//                                                  dataPersisted/error/canceled)
//
// Regenerate after editing:
//   dart run pigeon --input pigeons/messages.dart
// (output paths are configured below via @ConfigurePigeon).
//
// IMPORTANT — the two native SDKs are NOT symmetric. This schema is the
// normalized union of both. Every cross-platform divergence is marked TODO.
// Verified source references:
//   Android: com.creative.tools.network.scan.NetworkScan (+ builder + *Callback)
//   iOS:     ScanMyNetManager / ScanMyNetDelegate (ScanMyNet.swift)

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/src/main/kotlin/com/creativeadvtech/scanmynet_sdk/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.creativeadvtech.scanmynet_sdk'),
    swiftOut: 'ios/scanmynet_sdk/Sources/scanmynet_sdk/Messages.g.swift',
    swiftOptions: SwiftOptions(),
    dartPackageName: 'scanmynet_sdk',
  ),
)

// ---------------------------------------------------------------------------
// ENUMS
// ---------------------------------------------------------------------------

/// iOS `ScanMyNetConfiguration.Environment`. Android has no environment enum —
/// it takes an explicit [ScanConfig.baseUrl] string instead.
/// TODO(confirm): how iOS `environment` maps to an Android baseUrl, and whether
/// the host passes baseUrl OR environment. Native code maps explicitly; do NOT
/// rely on index parity.
enum ScanEnvironment {
  staging,
  production,
  testing,
}

/// Android `NetworkScanStep` — 13 values in source declaration order.
/// iOS has no equivalent enum (it emits a free-text stage label string), so on
/// iOS [ScanProgress.currentStep]/[nextStep] are null and [label] is set.
enum ScanStep {
  setup,
  routerUpnp,
  connectivityTest,
  speedTest,
  publicIpFetch,
  gpsLocationFetch,
  traceroute,
  wifiCongestionTest,
  wifiDiscovery,
  connectionQualityTest,
  lanDiscovery,
  additionalData,
  resultSubmission,
}

/// Android `NetworkScanResultStatus`. (Source declares
/// ERROR_SUBMISSION_FAILED, SUCCESS — we keep our own order and map explicitly
/// in native code, never by index.)
enum ScanResultStatus {
  success,
  submissionFailed,
}

/// Normalized error category across both platforms.
enum ScanErrorKind {
  /// Non-fatal, per-step failure. Android `NetworkScanError`;
  /// iOS `scanServiceFailed(type:error:)`. The scan continues.
  perStep,

  /// Terminal submission failure. Android `scan()` Single.onError;
  /// iOS `scanFailed`.
  submission,

  /// iOS `scanCanceled()`. Android has no cancel in this fork.
  canceled,
}

// ---------------------------------------------------------------------------
// DATA CLASSES
// ---------------------------------------------------------------------------

/// Flat configuration collapsing the Android 6-step builder and the iOS
/// `ScanMyNetConfiguration` into one message. The Android `Context` is supplied
/// by the plugin (applicationContext), so it is NOT a field here.
class ScanConfig {
  ScanConfig({
    required this.apiKey,
    this.userKey,
    this.appName,
    this.baseUrl,
    this.requestKey,
    this.environment,
  });

  /// MANDATORY on both. Android `ApiKey.apiKey`; iOS `configuration.apiKey`.
  String apiKey;

  /// Android `UserKey.userKey` (sent as ReportParamDto.key). iOS: not used.
  /// TODO(confirm): is iOS `requestKey` the same concept as Android `userKey`?
  String? userKey;

  /// Android `AppName.appName` (ReportParamDto.app). iOS: not used.
  String? appName;

  /// Android `BaseUrl.baseUrl` (Retrofit base). iOS selects backend via
  /// [environment] instead.
  String? baseUrl;

  /// iOS `ScanMyNetConfiguration.requestKey`. Android: not used.
  String? requestKey;

  /// iOS only. If null on iOS, native defaults to [ScanEnvironment.production].
  /// TODO(confirm) default environment.
  ScanEnvironment? environment;
}

/// Progress payload — superset of both platforms.
/// Android fills step/nextStep/percent/durationMs; iOS fills percent + label.
class ScanProgress {
  ScanProgress({
    required this.percent,
    this.currentStep,
    this.nextStep,
    this.label,
    this.durationMs,
  });

  /// 0..100. Native normalizes to this range.
  /// TODO(verify): Android `NetworkScanProgress.percent` is a Float documented
  /// as "percent of tests completed" — confirm 0..1 vs 0..100 and normalize in
  /// the Kotlin bridge to match iOS `scanProgress` (0..100).
  double percent;

  /// Android `NetworkScanProgress.currentStep`. Null on iOS.
  ScanStep? currentStep;

  /// Android `NetworkScanProgress.nextStep`. Null on iOS.
  ScanStep? nextStep;

  /// iOS stage label (`nextScanStarted(value)` / `serviceTriggered(log)`).
  /// Null on Android.
  String? label;

  /// Android `NetworkScanProgress.duration` (ms). Null on iOS.
  int? durationMs;
}

/// Terminal success. Android `ReportResponseDto.data`; iOS
/// `scanFinished(reportUrl:)`.
class ScanResult {
  ScanResult({
    required this.reportUrl,
    this.status,
    this.totalDurationMs,
  });

  /// The online report URL (Android value may carry a `verification_token`
  /// query param — leave parsing to Dart).
  String reportUrl;

  /// Android `NetworkScanResult.status`. iOS only emits on success -> SUCCESS.
  ScanResultStatus? status;

  /// Android `NetworkScanResult.duration` (total ms). Null on iOS.
  int? totalDurationMs;
}

/// Error payload. `Throwable`/`Error`/`HTTPURLResponse` are not channel-
/// encodable, so everything is flattened to primitives here.
class ScanError {
  ScanError({
    required this.kind,
    required this.message,
    this.step,
    this.serviceType,
  });

  ScanErrorKind kind;

  /// `Throwable.message` / `Error.localizedDescription` / raw response body.
  String message;

  /// Android `NetworkScanError.test` (per-step). Null on iOS.
  ScanStep? step;

  /// iOS `scanServiceFailed` type (`ServiceType.rawValue`). Null on Android.
  String? serviceType;
}

/// The "data persisted" payload — the full report submitted to the backend.
/// Android `DebugCallback` delivers a ~50-field `ReportParamDto`; rather than
/// re-model all 8 nested list types as Pigeon classes, we pass the SDK's
/// existing `ReportParamDto.toJson()` (Gson) string. iOS has no equivalent
/// debug callback, so this event does not fire on iOS.
/// TODO(decide): keep this event in v1, or defer richer typing to a later task.
class ScanReport {
  ScanReport({required this.reportJson});

  /// Android `ReportParamDto.toJson()`. Empty/unused on iOS.
  String reportJson;
}

// ---------------------------------------------------------------------------
// HOST API (Dart -> Native commands)
// ---------------------------------------------------------------------------

@HostApi()
abstract class ScanHostApi {
  /// Android: builds `NetworkScan` via the step-builder, wiring the 4 callbacks
  /// to [ScanFlutterApi], but does NOT subscribe yet.
  /// iOS: constructs `ScanMyNetManager(configuration:)` and assigns the
  /// delegate bridge. (init + config are fused on iOS.)
  void configure(ScanConfig config);

  /// Android: subscribes to `NetworkScan.scan()` (RxJava Single) on
  /// Schedulers.io and forwards onSuccess/onError to [ScanFlutterApi].
  /// iOS: calls `ScanMyNetManager.start()`.
  ///
  /// Intentionally NOT @async: the long-running result is delivered through
  /// [ScanFlutterApi] (onFinished / onError), not a Future. This also avoids
  /// double-delivery, since the result arrives via both the Rx Single AND the
  /// ResultCallback on Android.
  void startScan();

  /// iOS `ScanMyNetManager.cancel()`. Android has NO cancel in this fork.
  /// TODO: decide Android behavior — best-effort dispose of the Rx
  /// CompositeDisposable, or throw FlutterError("UNSUPPORTED").
  void cancel();
}

// ---------------------------------------------------------------------------
// FLUTTER API (Native -> Dart callbacks)
// ---------------------------------------------------------------------------

@FlutterApi()
abstract class ScanFlutterApi {
  /// Scan started. Android: first step (SETUP). iOS: `scanStarted()`.
  void onStarted();

  /// Per-step progress. Android `ProgressCallback.onProgress`; iOS
  /// `scanProgress` / `nextScanStarted`.
  void onProgress(ScanProgress progress);

  /// Scan complete + report submitted. Android `ResultCallback`/Single success;
  /// iOS `scanFinished(reportUrl:)`. (complete and dataPersisted are fused on
  /// iOS into this single event.)
  void onFinished(ScanResult result);

  /// "dataPersisted": the full submitted report payload. Android
  /// `DebugCallback.onResult` (ReportParamDto JSON). Does not fire on iOS.
  void onDataPersisted(ScanReport report);

  /// Any error state — per-step (non-fatal) or terminal submission failure.
  void onError(ScanError error);

  /// Scan canceled. iOS `scanCanceled()`. Never fires on Android (no cancel).
  void onCanceled();
}
