import 'dart:async';

import 'src/messages.g.dart';
import 'src/scan_events.dart';

export 'src/messages.g.dart';
export 'src/scan_events.dart';
export 'src/report_types.dart';

/// Public entry point for the ScanMyNet plugin.
///
/// Commands flow Dart -> native via simple async calls ([configure],
/// [startScan], [cancel]). Lifecycle events flow native -> Dart and are exposed
/// as a single broadcast [Stream] of [ScanEvent]s via [events]:
///
/// ```dart
/// final sdk = ScanmynetSdk();
/// sdk.events.listen((event) { /* switch over ScanEvent */ });
/// await sdk.configure(config);
/// await sdk.startScan();
/// ...
/// sdk.dispose();
/// ```
class ScanmynetSdk {
  /// Creates the plugin facade and begins forwarding native events to [events].
  /// A custom [hostApi] can be injected in tests.
  ScanmynetSdk({ScanHostApi? hostApi}) : _host = hostApi ?? ScanHostApi() {
    ScanFlutterApi.setUp(_ScanEventForwarder(_events));
  }

  final ScanHostApi _host;
  final StreamController<ScanEvent> _events =
      StreamController<ScanEvent>.broadcast();

  /// Pigeon schema version. Bump whenever fields are added to the schema.
  static const int schemaVersion = 2;

  /// Native scan lifecycle as a broadcast stream. Subscribe before calling
  /// [startScan] to receive every event.
  Stream<ScanEvent> get events => _events.stream;

  /// Convenience view of progress-only events.
  Stream<ScanProgress> get progress => events
      .where((e) => e is ScanProgressed)
      .map((e) => (e as ScanProgressed).progress);

  /// Configures the native SDK. Android builds the `NetworkScan`; iOS builds
  /// the `ScanMyNetManager`. Must be called before [startScan].
  Future<void> configure(ScanConfig config) {
    config.schemaVersion = schemaVersion;
    return _host.configure(config);
  }

  /// Starts a full network scan. Progress and the final result are delivered
  /// through [events], not returned here.
  Future<void> startScan() => _host.startScan();

  /// Cancels an in-flight scan. Supported on iOS; best-effort/no-op on Android
  /// (the native SDK fork has no cancel).
  Future<void> cancel() => _host.cancel();

  /// Detaches the native event handler and closes [events]. Call when the SDK
  /// is no longer needed.
  void dispose() {
    ScanFlutterApi.setUp(null);
    _events.close();
  }
}

/// Bridges the generated [ScanFlutterApi] callbacks into the [ScanEvent] stream.
class _ScanEventForwarder implements ScanFlutterApi {
  _ScanEventForwarder(this._sink);

  final StreamController<ScanEvent> _sink;

  void _emit(ScanEvent event) {
    if (!_sink.isClosed) _sink.add(event);
  }

  @override
  void onStarted() => _emit(const ScanStarted());

  @override
  void onProgress(ScanProgress progress) => _emit(ScanProgressed(progress));

  @override
  void onFinished(ScanResult result) => _emit(ScanCompleted(result));

  @override
  void onDataPersisted(ScanReport report) => _emit(ScanDataPersisted(report));

  @override
  void onError(ScanError error) => _emit(ScanFailed(error));

  @override
  void onCanceled() => _emit(const ScanCanceled());
}
