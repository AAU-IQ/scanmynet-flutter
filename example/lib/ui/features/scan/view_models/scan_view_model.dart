import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:scanmynet_sdk/scanmynet_sdk.dart';
import 'package:scanmynet_sdk_example/domain/models/scan_ui_state.dart';

/// Owns scan state and orchestrates the [ScanmynetSdk].
///
/// Subscribes to the SDK's [ScanEvent] stream and translates each event into an
/// immutable [ScanUiState] snapshot for the view. The view never touches the
/// SDK directly.
class ScanViewModel extends ChangeNotifier {
  ScanViewModel({
    required String apiKey,
    required String requestKey,
    required String appName,
    required ScanEnvironment environment,
    ScanmynetSdk? sdk,
  }) : _apiKey = apiKey,
       _requestKey = requestKey,
       _appName = appName,
       _environment = environment,
       _sdk = sdk ?? ScanmynetSdk() {
    _subscription = _sdk.events.listen(_onEvent);
  }

  final ScanmynetSdk _sdk;
  final String _apiKey;
  final String _requestKey;
  final String _appName;
  final ScanEnvironment _environment;
  late final StreamSubscription<ScanEvent> _subscription;

  ScanUiState _state = ScanUiState.idle;
  ScanUiState get state => _state;

  void _emit(ScanUiState next) {
    _state = next;
    notifyListeners();
  }

  /// Configures the SDK for [customerKey] against the selected [environment] and
  /// starts a scan. Progress and the final result arrive asynchronously on the
  /// SDK's event stream.
  Future<void> start({required String customerKey}) async {
    if (_state.isRunning) return;

    // Request permission before changing UI state so the system dialog appears
    // on the idle screen, not mid-scan. WiFi/router/GPS details require location
    // at runtime — without it Android anonymizes SSID/BSSID/make/model.
    final status = await Permission.location.request();
    if (!status.isGranted) {
      _emit(
        const ScanUiState(
          phase: ScanPhase.failed,
          errorMessage:
              'Location permission is required to read WiFi and router details.',
        ),
      );
      return;
    }

    _emit(const ScanUiState(phase: ScanPhase.running, stepLabel: 'starting…'));

    try {
      await _sdk.configure(
        ScanConfig(
          apiKey: _apiKey,
          requestKey: _requestKey,
          userKey: customerKey,
          appName: _appName,
          environment: _environment,
        ),
      );
      await _sdk.startScan();
    } catch (e) {
      _emit(ScanUiState(phase: ScanPhase.failed, errorMessage: e.toString()));
    }
  }

  /// Maps a native [ScanEvent] onto the UI state.
  void _onEvent(ScanEvent event) {
    switch (event) {
      case ScanStarted():
        _emit(_state.copyWith(phase: ScanPhase.running, stepLabel: 'started'));
      case ScanProgressed(:final progress):
        _emit(
          _state.copyWith(
            phase: ScanPhase.running,
            percent: progress.percent,
            stepLabel: progress.currentStep?.name ?? progress.label,
          ),
        );
      case ScanCompleted(:final result):
        final raw = result.reportUrl;
        _emit(
          ScanUiState(
            phase: ScanPhase.finished,
            percent: 100,
            reportUrl: raw.isEmpty ? null : raw,
          ),
        );
      case ScanFailed(:final error):
        // Per-step errors are non-fatal and the scan continues; only a terminal
        // submission failure should fail the UI.
        if (error.kind == ScanErrorKind.submission) {
          _emit(
            ScanUiState(
              phase: ScanPhase.failed,
              percent: _state.percent,
              errorMessage: error.message,
            ),
          );
        }
      case ScanCanceled():
        _emit(ScanUiState.idle);
      case ScanDataPersisted():
        // The full submitted report JSON (Android only); not surfaced here.
        break;
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    _sdk.dispose();
    super.dispose();
  }
}
