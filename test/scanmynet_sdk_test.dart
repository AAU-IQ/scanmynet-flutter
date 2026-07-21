import 'package:flutter_test/flutter_test.dart';
import 'package:scanmynet_sdk/scanmynet_sdk.dart';

/// Fake host API that records calls instead of crossing the platform channel.
/// Extends the generated [ScanHostApi] so it inherits the constructor and we
/// only override the command methods.
class _FakeScanHostApi extends ScanHostApi {
  ScanConfig? configuredWith;
  bool started = false;
  bool canceled = false;

  @override
  Future<void> configure(ScanConfig config) async => configuredWith = config;

  @override
  Future<void> startScan() async => started = true;

  @override
  Future<void> cancel() async => canceled = true;
}

void main() {
  // ScanmynetSdk()'s constructor calls ScanFlutterApi.setUp, which reaches for
  // the binary messenger and therefore needs the test binding initialized.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeScanHostApi fake;
  late ScanmynetSdk sdk;

  setUp(() {
    fake = _FakeScanHostApi();
    sdk = ScanmynetSdk(hostApi: fake);
  });

  test('configure forwards the config to the host API', () async {
    final config = ScanConfig(apiKey: 'key', userKey: 'user');
    await sdk.configure(config);
    expect(fake.configuredWith, same(config));
  });

  test('startScan forwards to the host API', () async {
    await sdk.startScan();
    expect(fake.started, isTrue);
  });

  test('cancel forwards to the host API', () async {
    await sdk.cancel();
    expect(fake.canceled, isTrue);
  });

  test('configure stamps the schema version onto the config', () async {
    final config = ScanConfig(apiKey: 'key');
    await sdk.configure(config);
    expect(fake.configuredWith!.schemaVersion, ScanmynetSdk.schemaVersion);
  });
}
