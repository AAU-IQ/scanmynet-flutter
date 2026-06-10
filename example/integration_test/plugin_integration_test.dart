// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:scanmynet_sdk/scanmynet_sdk.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // The native SDKs are linked in the T2 (Android) / T3 (iOS) tasks; until then
  // the native impls are no-ops. This smoke test verifies the plugin's channel
  // wiring is registered — calling a HostApi method must complete without
  // throwing a MissingPluginException.
  testWidgets('configure round-trips over the platform channel',
      (WidgetTester tester) async {
    final ScanmynetSdk plugin = ScanmynetSdk();
    await plugin.configure(ScanConfig(apiKey: 'test-key'));
    // No throw == the ScanHostApi handler is registered on the host side.
  });
}
