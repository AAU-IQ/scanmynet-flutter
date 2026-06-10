import 'package:flutter/material.dart';
import 'package:scanmynet_sdk/scanmynet_sdk.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

/// Demonstrates the plugin: implement [ScanFlutterApi] to receive scan events,
/// register it, then [ScanmynetSdk.configure] + [ScanmynetSdk.startScan].
///
/// NOTE: the native SDKs are not linked yet (that is the T2/T3 work), so the
/// skeleton native impls are no-ops — this screen exercises the channel wiring,
/// not a real scan.
class _MyAppState extends State<MyApp> implements ScanFlutterApi {
  final _sdk = ScanmynetSdk();
  String _status = 'idle';

  @override
  void initState() {
    super.initState();
    _sdk.setListener(this);
  }

  Future<void> _runScan() async {
    setState(() => _status = 'configuring…');
    await _sdk.configure(
      ScanConfig(
        apiKey: 'YOUR_API_KEY',
        userKey: 'demo-user',
        appName: 'scanmynet_sdk example',
        baseUrl: 'https://scanmynet-backend.dev.kvm.creativeadvtech.ml/api/v1/',
      ),
    );
    setState(() => _status = 'starting…');
    await _sdk.startScan();
  }

  // --- ScanFlutterApi (native -> Dart) -------------------------------------

  @override
  void onStarted() => setState(() => _status = 'started');

  @override
  void onProgress(ScanProgress progress) {
    final where = progress.currentStep?.name ?? progress.label ?? '';
    setState(
      () => _status = 'progress ${progress.percent.toStringAsFixed(0)}% $where',
    );
  }

  @override
  void onFinished(ScanResult result) =>
      setState(() => _status = 'finished: ${result.reportUrl}');

  @override
  void onDataPersisted(ScanReport report) {
    // The full submitted report JSON (Android only); ignored in this demo.
  }

  @override
  void onError(ScanError error) =>
      setState(() => _status = 'error (${error.kind.name}): ${error.message}');

  @override
  void onCanceled() => setState(() => _status = 'canceled');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('ScanMyNet SDK example')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_status, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _runScan,
                child: const Text('Run scan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
