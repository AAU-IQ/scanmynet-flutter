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

  /// Rolling, timestamped feed of native scan events — useful for diagnosing
  /// where a scan stalls (e.g. the SDK pausing on the traceroute step). Capped
  /// so it can't grow unbounded during a long scan.
  static const _maxLogLines = 300;
  final List<String> _logs = <String>[];
  List<String> get logs => List.unmodifiable(_logs);

  void _log(String message) {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
    _logs.add('$stamp  $message');
    if (_logs.length > _maxLogLines) _logs.removeAt(0);
    notifyListeners();
  }

  AppEnvironment _environment = kDefaultEnvironment;
  AppEnvironment get environment => _environment;

  /// Switches the target environment (ignored mid-scan).
  void selectEnvironment(AppEnvironment env) {
    if (_state.isRunning || env == _environment) return;
    _environment = env;
    notifyListeners();
  }

  void _emit(ScanUiState next) {
    _state = next;
    notifyListeners();
  }

  /// Configures the SDK for [customerKey] against the selected [environment] and
  /// starts a scan. Progress and the final result arrive asynchronously on the
  /// SDK's event stream.
  Future<void> start({required String customerKey}) async {
    if (_state.isRunning) return;

    _logs.clear();
    _log('requesting location permission…');

    // Request permission before changing UI state so the system dialog appears
    // on the idle screen, not mid-scan. WiFi/router/GPS details require location
    // at runtime — without it Android anonymizes SSID/BSSID/make/model.
    final status = await Permission.location.request();
    _log('location permission: ${status.name}');
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
      _log('configure (env: ${_environment.label})');
      await _sdk.configure(
        ScanConfig(
          apiKey: _apiKey,
          requestKey: _requestKey,
          userKey: customerKey,
          appName: _appName,
          environment: _environment,
        ),
      );
      _log('startScan()');
      await _sdk.startScan();
    } catch (e) {
      _log('exception: $e');
      _emit(ScanUiState(phase: ScanPhase.failed, errorMessage: e.toString()));
    }
  }

  /// Cancels an in-flight scan. iOS supports this (the SDK stops its services
  /// and emits `onCanceled`); on Android it is best-effort. Useful to recover
  /// from a step that stalls — e.g. the traceroute waiting on an unreachable
  /// host.
  Future<void> cancel() async {
    if (!_state.isRunning) return;
    _log('cancel() requested');
    await _sdk.cancel();
  }

  /// Maps a native [ScanEvent] onto the UI state.
  void _onEvent(ScanEvent event) {
    switch (event) {
      case ScanStarted():
        _log('▶ started');
        _emit(_state.copyWith(phase: ScanPhase.running, stepLabel: 'started'));
      case ScanProgressed(:final progress):
        final detail = progress.currentStep?.name ?? progress.label ?? '';
        _log('· ${progress.percent.toStringAsFixed(0)}% $detail'.trimRight());
        _emit(
          _state.copyWith(
            phase: ScanPhase.running,
            percent: progress.percent,
            stepLabel: progress.currentStep?.name ?? progress.label,
          ),
        );
      case ScanCompleted(:final result):
        _log('✓ finished: ${result.reportUrl}');
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
        _log('✕ error[${error.kind.name}]'
            '${error.serviceType != null ? ' ${error.serviceType}' : ''}: '
            '${error.message}');
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
        _log('canceled');
        _emit(ScanUiState.idle);
      case ScanDataPersisted():
        // The full submitted report JSON (Android only); not surfaced here.
        _log('data persisted');
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
