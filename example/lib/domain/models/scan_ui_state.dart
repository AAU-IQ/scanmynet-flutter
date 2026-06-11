import 'package:flutter/foundation.dart';

/// Lifecycle phase of a scan, used to drive the UI.
enum ScanPhase { idle, running, finished, failed }

/// Immutable snapshot of the scan UI state, exposed by the view-model.
@immutable
class ScanUiState {
  const ScanUiState({
    this.phase = ScanPhase.idle,
    this.percent = 0,
    this.stepLabel,
    this.reportUrl,
    this.errorMessage,
  });

  /// Convenience constant for the initial state.
  static const idle = ScanUiState();

  final ScanPhase phase;

  /// Overall progress, 0..100.
  final double percent;

  /// Human-readable current step (e.g. `speedTest`), when running.
  final String? stepLabel;

  /// URL of the generated report, when finished.
  final String? reportUrl;

  /// Terminal error message, when failed.
  final String? errorMessage;

  bool get isRunning => phase == ScanPhase.running;
  bool get isFinished => phase == ScanPhase.finished;
  bool get hasFailed => phase == ScanPhase.failed;

  ScanUiState copyWith({
    ScanPhase? phase,
    double? percent,
    String? stepLabel,
    String? reportUrl,
    String? errorMessage,
  }) {
    return ScanUiState(
      phase: phase ?? this.phase,
      percent: percent ?? this.percent,
      stepLabel: stepLabel ?? this.stepLabel,
      reportUrl: reportUrl ?? this.reportUrl,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
