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

/// Selects the backend both platforms talk to. iOS maps it onto
/// `ScanMyNetConfiguration.Environment`; Android maps it to the matching
/// Retrofit base URL internally. Null defaults to [ScanEnvironment.production].
/// Native code maps explicitly by case — do NOT rely on index parity.
enum ScanEnvironment {
  staging,
  production,
  dev,

  /// A self-hosted deployment — an operator running their own ScanMyNet backend
  /// rather than ours. Requires [ScanConfig.customBaseUrl]; [configure] rejects
  /// the pair if it is missing.
  ///
  /// Pigeon enums cannot carry associated values, so the URL travels alongside
  /// the selector rather than inside it. The iOS SDK's own `Environment` does
  /// have an associated value — the bridge recombines the two into
  /// `.custom(baseUrl:frontendUrl:)`.
  ///
  /// Declared LAST so the existing wire values 0/1/2 keep their meaning.
  custom,
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

  /// iOS `ScanMyNetConfiguration.requestKey`. Android: not used.
  String? requestKey;

  /// Backend selector, honoured on both platforms. Null defaults to
  /// [ScanEnvironment.production].
  ScanEnvironment? environment;

  /// Pigeon schema version, set by the Dart layer. Native compares it against
  /// its own compiled-in constant and throws on mismatch — codecs are
  /// positional, so a skewed pair misreads fields silently rather than failing.
  ///
  /// Keep this field's POSITION stable when adding to this class: a stale native
  /// binary reads the version by index, and if a newly-inserted field shifted it,
  /// the mismatch check would read null and pass silently — defeating the very
  /// guard it exists to be. New fields go below.
  int? schemaVersion;

  /// Server root for [ScanEnvironment.custom] — e.g. `https://smn.example.com/`.
  /// Not an endpoint: each SDK still appends its own `/api/v1/…` paths, so the
  /// deployment must expose the same endpoint names ours does. The trailing
  /// slash is optional; native normalizes it.
  ///
  /// Ignored unless [environment] is [ScanEnvironment.custom].
  String? customBaseUrl;

  /// Report-viewer root for [ScanEnvironment.custom]. The backend returns a
  /// report's `verification_token` but not a usable viewer link, so the
  /// shareable URL is assembled client-side from this root plus the token.
  ///
  /// Optional — defaults to [customBaseUrl] when the same host serves both.
  String? customFrontendUrl;
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
    this.reportId,
    this.customerId,
    this.report,
  });

  /// The online report URL (Android value may carry a `verification_token`
  /// query param — leave parsing to Dart).
  String reportUrl;

  /// Android `NetworkScanResult.status`. iOS only emits on success -> SUCCESS.
  ScanResultStatus? status;

  /// Android `NetworkScanResult.duration` (total ms). Null on iOS.
  int? totalDurationMs;

  /// Backend report identifier. Lets you correlate a scan without parsing the
  /// JWT in [reportUrl]. Null on backends predating the payload.
  String? reportId;

  /// Subscriber/customer key the report was filed under.
  String? customerId;

  /// The full report payload. Null when the backend omitted it.
  ReportData? report;
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
// REPORT PAYLOAD (response) — mirrors POST /report/ `report` object.
//
// NOTE: this is the RESPONSE report. `ScanReport` above is the REQUEST payload
// that was submitted. They are different objects; do not merge them.
//
// Every field is nullable: sections are built from whatever the scan submitted,
// and several keys are absent entirely rather than null.
// ---------------------------------------------------------------------------

/// A `{quality, color}` pair. NOT the same shape as
/// [InternetSpeed.connectionQuality], which is a single-entry map.
class QualityColor {
  QualityColor({this.quality, this.color});
  String? quality;
  String? color;
}

/// A `{status, color}` roll-up pair.
class StatusColor {
  StatusColor({this.status, this.color});
  String? status;
  String? color;
}

/// A report alert. [alertType] is a String, never an enum — new members ship
/// without an API version bump. Branch on [alertType], never [alertValue].
class ReportAlert {
  ReportAlert({this.alertType, this.alertValue});
  String? alertType;
  String? alertValue;
}

/// A report recommendation. Field names differ from [ReportAlert]:
/// actions use `action_*`, alerts use `alert_*`.
class ReportAction {
  ReportAction({this.actionType, this.actionValue});
  String? actionType;
  String? actionValue;
}

class CustomerDetails {
  CustomerDetails({this.key, this.lastKnownPublicIp, this.lastKnownPublicIpDetails});
  String? key;
  String? lastKnownPublicIp;
  /// Capitalised keys (`Country`, `Region`, `ISP`). Passed through verbatim.
  Map<String, String>? lastKnownPublicIpDetails;
}

class SdkDetails {
  SdkDetails({
    this.start, this.duration, this.platform, this.app, this.routeThisSdk,
    this.userPublicUpAddress, this.gpsLatitude, this.gpsLongitude,
  });
  String? start;
  /// Seconds.
  int? duration;
  String? platform;
  String? app;
  String? routeThisSdk;
  String? userPublicUpAddress;
  double? gpsLatitude;
  double? gpsLongitude;
}

/// Mbps.
class RouterUsage {
  RouterUsage({this.networkUsageDown, this.networkUsageUp});
  double? networkUsageDown;
  double? networkUsageUp;
}

class InternetSpeed {
  InternetSpeed({
    this.networkSpeedDown, this.networkSpeedUp, this.currentNegotiatedLinkSpeed,
    this.maximumLinkSupportedByPhone, this.networkSpeedUpSegments,
    this.networkSpeedDownSegments, this.connectionQuality,
  });
  double? networkSpeedDown;
  double? networkSpeedUp;
  double? currentNegotiatedLinkSpeed;
  String? maximumLinkSupportedByPhone;
  List<double>? networkSpeedUpSegments;
  List<double>? networkSpeedDownSegments;
  /// SINGLE-ENTRY map keyed by the quality label, e.g. `{"good": "green"}`.
  /// NOT a [QualityColor] struct.
  Map<String, String>? connectionQuality;
}

class ServerConnectivityResult {
  ServerConnectivityResult({this.name, this.serverStatus});
  String? name;
  bool? serverStatus;
}

class PortCheckResult {
  PortCheckResult({this.port, this.portType, this.description, this.portStatus});
  int? port;
  String? portType;
  String? description;
  bool? portStatus;
}

class DnsLookupResult {
  DnsLookupResult({this.dnsIp, this.alias, this.reverseDns});
  String? dnsIp;
  String? alias;
  String? reverseDns;
}

/// The three entries do NOT share a type: [dnsLookup] is a list of alias
/// strings while its siblings are objects.
class ConnectivitySummary {
  ConnectivitySummary({this.serverConnectivity, this.portChecks, this.dnsLookup});
  StatusColor? serverConnectivity;
  StatusColor? portChecks;
  List<String>? dnsLookup;
}

/// Firewall / client isolation / multicast. [value] is the STRING
/// `"Enabled"` / `"Disabled"`, never a bool.
class ToggleState {
  ToggleState({this.value, this.color, this.status, this.alert});
  String? value;
  String? color;
  String? status;
  /// Single alert object, not a list. Null when no alert applies.
  ReportAlert? alert;
}

class BasicConnectivity {
  BasicConnectivity({
    this.ipAssignedViaDhcp, this.serverConnectivity, this.portChecks,
    this.dnsLookup, this.summary, this.blockedServers, this.blockedUdpPorts,
    this.blockedTcpPorts, this.firewall, this.clientIsolation, this.multicast,
  });
  bool? ipAssignedViaDhcp;
  List<ServerConnectivityResult>? serverConnectivity;
  List<PortCheckResult>? portChecks;
  List<DnsLookupResult>? dnsLookup;
  ConnectivitySummary? summary;
  /// Blocked server names (payload key `servers`).
  List<String>? blockedServers;
  /// Blocked UDP ports (payload key `udp`).
  List<int>? blockedUdpPorts;
  /// Blocked TCP ports (payload key `tcp`).
  List<int>? blockedTcpPorts;
  ToggleState? firewall;
  ToggleState? clientIsolation;
  ToggleState? multicast;
  // NOTE: the payload's `basic_connectivity.alerts` is always empty — real
  // alerts are promoted to ReportData.alerts. Deliberately not modelled.
}

/// Third-party (Fing) recognition. [recognition] is an open payload.
class DeviceRecognition {
  DeviceRecognition({this.mac, this.recognition});
  String? mac;
  Map<String, Object?>? recognition;
}

class LocalConnectedDevice {
  LocalConnectedDevice({
    this.deviceName, this.deviceIp, this.deviceMacAddress, this.manufacturer,
    this.packetsDropped, this.numPacketsSent, this.pingValues,
    this.isSubscriberPhone, this.averagePingTime, this.connectionQualityColor,
    this.isSubscriberRouter, this.deviceDetails,
  });
  String? deviceName;
  String? deviceIp;
  String? deviceMacAddress;
  String? manufacturer;
  double? packetsDropped;
  int? numPacketsSent;
  List<double>? pingValues;
  bool? isSubscriberPhone;
  /// `0` (not null) when [pingValues] is empty.
  double? averagePingTime;
  QualityColor? connectionQualityColor;
  bool? isSubscriberRouter;
  /// Null when device recognition did not run.
  DeviceRecognition? deviceDetails;
}

class CustomerRouterDetails {
  CustomerRouterDetails({
    this.make, this.model, this.encryption, this.protocols, this.mesh,
    this.routerIpAddress, this.routerMacAddress, this.manufacturer,
    this.hostname, this.modelDescription, this.modelNumber, this.friendlyName,
    this.deviceType, this.routerDetails,
  });
  String? make;
  String? model;
  String? encryption;
  String? protocols;
  String? mesh;
  String? routerIpAddress;
  String? routerMacAddress;
  String? manufacturer;
  String? hostname;
  String? modelDescription;
  String? modelNumber;
  String? friendlyName;
  String? deviceType;
  /// Present only when [routerMacAddress] is non-null.
  DeviceRecognition? routerDetails;
}

class OtherRouterDetail {
  OtherRouterDetail({this.ip, this.asn, this.owner});
  String? ip;
  /// Autonomous system number. Null for private hops and until the GeoLite2-ASN
  /// database is provisioned server-side.
  int? asn;
  /// `"Private"` for RFC-1918 addresses regardless of database state; null for
  /// public addresses until the ASN database is provisioned.
  String? owner;
}

class DoubleNat {
  DoubleNat({this.isDoubleNat, this.doubleNatHop});
  bool? isDoubleNat;
  List<String>? doubleNatHop;
}

class NetworkTopology {
  NetworkTopology({
    this.routerIpAddress, this.otherRouters, this.otherRoutersDetails,
    this.doubleNatDetected,
  });
  String? routerIpAddress;
  /// De-duplicated, ordered by first appearance across traceroute hops.
  List<String>? otherRouters;
  List<OtherRouterDetail>? otherRoutersDetails;
  /// Null means NO double NAT — the key is absent in that case, not false.
  DoubleNat? doubleNatDetected;
}

/// [frequency] is GHz. [signalStrength] is dBm (negative).
class WifiNetworkResult {
  WifiNetworkResult({
    this.ssid, this.ssidIp, this.bssid, this.encryption, this.frequency,
    this.wpsAvailability, this.signalStrength, this.numWifiChannels,
    this.channelWidth, this.currentChannel, this.isSubscriberSsid,
  });
  String? ssid;
  String? ssidIp;
  String? bssid;
  String? encryption;
  double? frequency;
  bool? wpsAvailability;
  int? signalStrength;
  int? numWifiChannels;
  int? channelWidth;
  int? currentChannel;
  bool? isSubscriberSsid;
}

/// [numPhoneWifiChannel] is the COUNT of congestion entries, not a channel
/// number — the channel is [phoneWifiChannel].
class UserConnection {
  UserConnection({
    this.phoneWifiFrequency, this.numPhoneWifiChannel,
    this.numNetworksOnChannel, this.phoneWifiChannel,
  });
  double? phoneWifiFrequency;
  int? numPhoneWifiChannel;
  int? numNetworksOnChannel;
  int? phoneWifiChannel;
}

/// [index] is a STRING in the payload, not an int.
class ChannelCongestion {
  ChannelCongestion({this.index, this.numNetworks});
  String? index;
  int? numNetworks;
}

class CongestionEnvironment {
  CongestionEnvironment({this.channelCongestion, this.surroundingWifiNetworks});
  List<ChannelCongestion>? channelCongestion;
  /// Excludes the subscriber's own SSID.
  List<WifiNetworkResult>? surroundingWifiNetworks;
}

class NetworkCongestion {
  NetworkCongestion({this.userConnection, this.environment});
  UserConnection? userConnection;
  CongestionEnvironment? environment;
}

/// [layerRanking] is 1 (local), 2 (unknown/default) or 3 (external).
class DnsQuality {
  DnsQuality({
    this.dnsName, this.dnsIp, this.packetsDropped, this.numPacketsSent,
    this.pingValues, this.isSubscriberRouter, this.jitter, this.averagePingTime,
    this.connectionQualityColor, this.layerRanking,
  });
  String? dnsName;
  String? dnsIp;
  double? packetsDropped;
  int? numPacketsSent;
  List<double>? pingValues;
  /// True for the subscriber's own router.
  bool? isSubscriberRouter;
  double? jitter;
  double? averagePingTime;
  QualityColor? connectionQualityColor;
  int? layerRanking;
}

/// [rttValues] are integers in milliseconds.
class TracerouteHop {
  TracerouteHop({this.dnsIp, this.dnsName, this.rttValues});
  String? dnsIp;
  String? dnsName;
  List<int>? rttValues;
}

class TracerouteEntry {
  TracerouteEntry({this.dnsDestinationIp, this.hops});
  String? dnsDestinationIp;
  List<TracerouteHop>? hops;
}

/// The full report payload. Mirrors the FE contract and evolves with it — this
/// is NOT a stable versioned schema.
class ReportData {
  ReportData({
    this.customerDetails, this.sdkDetails, this.routerUsageDuringScan,
    this.customerInternetSpeed, this.basicConnectivity,
    this.localConnectedDevices, this.customerRouterDetails, this.networkTopology,
    this.userWifiNetwork, this.networkCongestion, this.connectionQuality,
    this.traceroute, this.alerts, this.actions, this.incompleteAnalysis,
  });
  CustomerDetails? customerDetails;
  SdkDetails? sdkDetails;
  RouterUsage? routerUsageDuringScan;
  InternetSpeed? customerInternetSpeed;
  BasicConnectivity? basicConnectivity;
  List<LocalConnectedDevice>? localConnectedDevices;
  CustomerRouterDetails? customerRouterDetails;
  NetworkTopology? networkTopology;
  WifiNetworkResult? userWifiNetwork;
  NetworkCongestion? networkCongestion;
  List<DnsQuality>? connectionQuality;
  List<TracerouteEntry>? traceroute;
  List<ReportAlert>? alerts;
  List<ReportAction>? actions;
  /// True when both `missing_upnp` and `incomplete_speed_test` fired — present
  /// the scan as unreliable.
  bool? incompleteAnalysis;
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
