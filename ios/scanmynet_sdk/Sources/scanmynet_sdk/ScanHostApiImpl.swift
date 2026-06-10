import Foundation

/// Skeleton `ScanHostApi` implementation.
///
/// The real wiring to `ScanMyNetManager` — building the `ScanMyNetConfiguration`,
/// assigning a `ScanMyNetDelegate` bridge that forwards to `flutterApi`, and
/// calling `start()` / `cancel()` — lands in the **T3 [iOS]** task. For now every
/// method is a documented no-op so the generated Pigeon code compiles and links
/// before the native SDK is added.
final class ScanHostApiImpl: ScanHostApi {
  private let flutterApi: ScanFlutterApi

  init(flutterApi: ScanFlutterApi) {
    self.flutterApi = flutterApi
  }

  func configure(config: ScanConfig) throws {
    // TODO(T3): build ScanMyNetManager(configuration: ScanMyNetConfiguration(
    //     apiKey: config.apiKey, requestKey: config.requestKey,
    //     environment: <map config.environment>)); assign a delegate bridge
    //     that forwards every delegate method to flutterApi on the main queue.
  }

  func startScan() throws {
    // TODO(T3): manager.start()
  }

  func cancel() throws {
    // TODO(T3): manager.cancel()
  }
}
