import 'package:flutter/material.dart';
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
  // Supply your own credentials and URLs here — never commit real values.
  late final ScanViewModel _viewModel = ScanViewModel(
    apiKey: 'YOUR_API_KEY',
    appName: 'YourAppName',
    baseUrl: 'YOUR_BACKEND_URL',
    reportBaseUrl: 'YOUR_REPORT_URL',
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
