import Flutter
import UIKit

/// ScanMyNet plugin entry point.
///
/// Registers the Pigeon-generated `ScanHostApi` handler (Dart -> native) and
/// constructs the `ScanFlutterApi` caller (native -> Dart) used to push scan
/// events back to Flutter.
public class ScanmynetSdkPlugin: NSObject, FlutterPlugin {
  private var hostApi: ScanHostApiImpl?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let instance = ScanmynetSdkPlugin()
    let flutterApi = ScanFlutterApi(binaryMessenger: messenger)
    instance.hostApi = ScanHostApiImpl(flutterApi: flutterApi)
    ScanHostApiSetup.setUp(binaryMessenger: messenger, api: instance.hostApi)
    // Retain the plugin (and its host-api impl) for the engine's lifetime.
    registrar.publish(instance)
  }
}
