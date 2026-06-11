import 'messages.g.dart';

/// A lifecycle event emitted by the native scanner, surfaced to Dart as a
/// single [Stream] (see `ScanmynetSdk.events`).
///
/// Pattern-match with a `switch` to handle each case:
/// ```dart
/// sdk.events.listen((event) {
///   switch (event) {
///     case ScanProgressed(:final progress): // update UI
///     case ScanCompleted(:final result):    // show report
///     case ScanFailed(:final error):        // show error
///     case ScanStarted():
///     case ScanDataPersisted():
///     case ScanCanceled():
///   }
/// });
/// ```
sealed class ScanEvent {
  const ScanEvent();
}

/// The native scan has started running.
class ScanStarted extends ScanEvent {
  const ScanStarted();
}

/// A progress update for the current step.
class ScanProgressed extends ScanEvent {
  const ScanProgressed(this.progress);
  final ScanProgress progress;
}

/// The scan finished and a report is available.
class ScanCompleted extends ScanEvent {
  const ScanCompleted(this.result);
  final ScanResult result;
}

/// The full submitted report payload was persisted (Android `debugCallback`).
class ScanDataPersisted extends ScanEvent {
  const ScanDataPersisted(this.report);
  final ScanReport report;
}

/// An error occurred. [ScanError.kind] distinguishes a recoverable per-step
/// error from a terminal submission failure.
class ScanFailed extends ScanEvent {
  const ScanFailed(this.error);
  final ScanError error;
}

/// The scan was canceled (iOS).
class ScanCanceled extends ScanEvent {
  const ScanCanceled();
}
