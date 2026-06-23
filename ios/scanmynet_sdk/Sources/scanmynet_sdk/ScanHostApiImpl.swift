import Foundation
import ScanMyNet

/// Bridges the Pigeon `ScanHostApi` (Dart -> native) onto the RouteThis
/// `ScanMyNet` SDK (`ScanMyNetManager` / `ScanMyNetDelegate`), and forwards the
/// SDK's delegate callbacks back to Dart through `flutterApi`.
///
/// Threading: the SDK drives its services off background queues, so delegate
/// callbacks may arrive on any thread — but the Pigeon channel must be invoked
/// on the main thread. Every `flutterApi` call is therefore funnelled through
/// `onMain`.
///
/// This is the iOS counterpart of the Android `ScanHostApiImpl`. The two SDKs
/// are NOT symmetric (see `pigeons/messages.dart`): iOS has no per-step enum and
/// no "data persisted" debug callback, so `ScanProgress.currentStep`/`nextStep`
/// stay nil (the free-text stage is sent as `label`) and `onDataPersisted` never
/// fires.
final class ScanHostApiImpl: NSObject, ScanHostApi {
  private let flutterApi: ScanFlutterApi
  private var manager: ScanMyNetManager?

  /// The SDK reports `nextScanStarted`/`serviceTriggered` (a label, no percent)
  /// and `scanProgress` (a percent, no label) on separate callbacks. We retain
  /// the last known percent so every `ScanProgress` we emit carries both.
  private var lastPercent: Double = 0

  init(flutterApi: ScanFlutterApi) {
    self.flutterApi = flutterApi
    super.init()
  }

  // MARK: - ScanHostApi (Dart -> native)

  func configure(config: ScanConfig) throws {
    lastPercent = 0
    let configuration = ScanMyNetConfiguration(
      apiKey: config.apiKey,
      requestKey: config.requestKey,
      environment: config.environment.toNative()
    )
    let manager = ScanMyNetManager(configuration: configuration)
    manager.delegate = self
    self.manager = manager
  }

  func startScan() throws {
    guard let manager = manager else {
      throw PigeonError(
        code: "NOT_CONFIGURED",
        message: "configure() must be called before startScan()",
        details: nil
      )
    }
    lastPercent = 0
    manager.start()
  }

  func cancel() throws {
    manager?.cancel()
  }

  // MARK: - Helpers

  private func onMain(_ block: @escaping () -> Void) {
    if Thread.isMainThread {
      block()
    } else {
      DispatchQueue.main.async(execute: block)
    }
  }
}

// MARK: - ScanMyNetDelegate (native -> Dart)

extension ScanHostApiImpl: ScanMyNetDelegate {

  func scanStarted() {
    onMain { self.flutterApi.onStarted { _ in } }
  }

  func scanProgress(value: Float) {
    lastPercent = Double(value)
    let progress = ScanProgress(percent: lastPercent)
    onMain { self.flutterApi.onProgress(progress: progress) { _ in } }
  }

  func nextScanStarted(value: String) {
    let progress = ScanProgress(percent: lastPercent, label: value)
    onMain { self.flutterApi.onProgress(progress: progress) { _ in } }
  }

  func serviceTriggered(log: String) {
    let progress = ScanProgress(percent: lastPercent, label: log)
    onMain { self.flutterApi.onProgress(progress: progress) { _ in } }
  }

  func scanFinished(reportUrl: String) {
    let result = ScanResult(reportUrl: reportUrl, status: .success)
    onMain { self.flutterApi.onFinished(result: result) { _ in } }
  }

  func scanServiceFailed(type: String, with error: Error) {
    let scanError = ScanError(
      kind: .perStep,
      message: error.localizedDescription,
      serviceType: type
    )
    onMain { self.flutterApi.onError(error: scanError) { _ in } }
  }

  func scanFailed(with error: Error, response: String) {
    let message = response.isEmpty ? error.localizedDescription : response
    let scanError = ScanError(kind: .submission, message: message)
    onMain { self.flutterApi.onError(error: scanError) { _ in } }
  }

  func scanCanceled() {
    onMain { self.flutterApi.onCanceled { _ in } }
  }

  /// Debug-only callback (request/response inspection). Not part of the Pigeon
  /// contract — there is no corresponding `ScanFlutterApi` event — so we ignore it.
  func getRequestData(request: URLRequest?, response: HTTPURLResponse?, error: Error?) {}
}

// MARK: - Enum mapping (Pigeon -> native)

private extension Optional where Wrapped == ScanEnvironment {
  /// Maps the Pigeon environment onto the SDK's `Environment`. The schema
  /// documents production as the default when the host sends nil.
  func toNative() -> Environment {
    switch self {
    case .staging: return .staging
    case .production: return .production
    // Pigeon `.dev` maps to the SDK's `testing` backend (the dev server).
    case .dev: return .testing
    case .none: return .production
    }
  }
}
