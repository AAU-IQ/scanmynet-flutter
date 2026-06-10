import 'src/messages.g.dart';

export 'src/messages.g.dart';

/// Public entry point for the ScanMyNet plugin.
///
/// Commands flow Dart -> native via [configure], [startScan] and [cancel].
/// Lifecycle events flow native -> Dart to a [ScanFlutterApi] you supply with
/// [setListener] (implement [ScanFlutterApi] in your app to receive
/// started / progress / finished / dataPersisted / error / canceled events).
class ScanmynetSdk {
  /// Creates the plugin facade. A custom [hostApi] can be injected in tests.
  ScanmynetSdk({ScanHostApi? hostApi}) : _host = hostApi ?? ScanHostApi();

  final ScanHostApi _host;

  /// Registers the listener that receives scan events from the native SDK.
  /// Pass `null` to unregister.
  void setListener(ScanFlutterApi? listener) => ScanFlutterApi.setUp(listener);

  /// Configures the native SDK. Android builds the `NetworkScan`; iOS builds
  /// the `ScanMyNetManager`. Must be called before [startScan].
  Future<void> configure(ScanConfig config) => _host.configure(config);

  /// Starts a full network scan. Progress and the final result are delivered
  /// to the listener registered via [setListener], not returned here.
  Future<void> startScan() => _host.startScan();

  /// Cancels an in-flight scan. Supported on iOS; best-effort/no-op on Android
  /// (the native SDK fork has no cancel).
  Future<void> cancel() => _host.cancel();
}
