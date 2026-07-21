import 'package:flutter/material.dart';
import 'package:scanmynet_sdk/scanmynet_sdk.dart';
import 'package:scanmynet_sdk_example/ui/core/theme.dart';
import 'package:scanmynet_sdk_example/ui/features/scan/view_models/scan_view_model.dart';
import 'package:scanmynet_sdk_example/ui/features/scan/views/scan_page.dart';

/// Root widget. Owns the [ScanViewModel] lifecycle and injects it into the
/// view (lightweight dependency injection for a single-screen example).
class ScanMyNetApp extends StatefulWidget {
  const ScanMyNetApp({super.key});

  @override
  State<ScanMyNetApp> createState() => _ScanMyNetAppState();
}

class _ScanMyNetAppState extends State<ScanMyNetApp> {
  // Supply your ScanMyNet credentials at build time:
  //   flutter run --dart-define=SMN_API_KEY=your-key
  // The report request returns 401 without a valid key.
  static const _apiKey = String.fromEnvironment('SMN_API_KEY');

  late final ScanViewModel _viewModel = ScanViewModel(
    apiKey: _apiKey,
    requestKey: 'QA-KEY',
    appName: 'ScanMyNet',
    environment: ScanEnvironment.dev,
  );

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: ScanPage(viewModel: _viewModel),
    );
  }
}
