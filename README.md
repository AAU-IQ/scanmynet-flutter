# scanmynet_sdk

Flutter plugin for the ScanMyNet network diagnostics SDK — wraps the native
Android **and iOS** SDKs to run a full home-network scan (speed test, DNS,
traceroute, device discovery) and submit results as a report to the ScanMyNet
backend.

## Install

```yaml
dependencies:
  scanmynet_sdk: ^1.0.0
```

## Prerequisites

| Tool | Version |
|------|---------|
| Flutter / Dart | ≥ 3.3.0 / ^3.12.0 |
| Android SDK | compileSdk 36, minSdk 24 |
| Java | 17 |
| iOS / CocoaPods | deployment target ≥ 13.0 |
| Xcode | 15+ |
| FVM (recommended) | any |

## Platform setup

### Android

No extra setup required — the private native AARs are bundled in
[android/local-maven-repo/](android/local-maven-repo/) and resolved automatically at build time.

### iOS

The native iOS SDK ships as the bundled `ios/ScanMyNet.xcframework` (the
counterpart of the Android AARs). Its four third-party Swift dependencies
(`Alamofire`, `XMLCoder`, `BlueSocket`, `NDT7`) are declared in
`ios/scanmynet_sdk.podspec` and resolved from the public CocoaPods trunk during
`pod install`.

> **Required:** the framework is compiled with library evolution, so its Swift
> dependencies must be rebuilt the same way in the host app — otherwise the app
> crashes at launch with a dyld `Symbol not found` error. Add this to your app's
> `ios/Podfile` `post_install` (already present in `example/ios/Podfile`):
>
> ```ruby
> post_install do |installer|
>   installer.pods_project.targets.each do |target|
>     flutter_additional_ios_build_settings(target)
>     if %w[Alamofire XMLCoder BlueSocket NDT7].include?(target.name)
>       target.build_configurations.each do |config|
>         config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
>       end
>     end
>   end
> end
> ```

### Permissions (iOS)

Declare both of these in your app's `Info.plist` — both are read at runtime:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Location is used to read WiFi and router details during a network scan.</string>
<key>NSLocalNetworkUsageDescription</key>
<string>Local network access is used to discover devices and your router during a network scan.</string>
```

**Without `NSLocationWhenInUseUsageDescription`, the report's
`userWifiNetwork` section (`user_wifi_network`) comes back empty** — iOS
withholds Wi-Fi/router details when location access hasn't been granted.
`NSLocalNetworkUsageDescription` is required for LAN/SSDP device discovery.

## Building the example app

```bash
cd example
fvm flutter pub get
fvm flutter build apk --release "--dart-define=SMN_API_KEY=<your-api-key>"
```

The signed APK is written to:
```
example/build/app/outputs/flutter-apk/app-release.apk
```

```bash
cd example
fvm flutter build ios --release "--dart-define=SMN_API_KEY=<your-api-key>"
```

### Environment variables / dart-defines

| Key | Required | Description |
|-----|----------|--------------|
| `SMN_API_KEY` | Yes | API key sent as `api-key` header to the backend |

Pass via `--dart-define=SMN_API_KEY=...` — **never** hardcode in source.

## Quickstart

```dart
final sdk = ScanmynetSdk();

sdk.events.listen((event) {
  switch (event) {
    case ScanProgressed(:final progress):
      print('${progress.percent}%');
    case ScanCompleted(:final result):
      print('Hosted report: ${result.reportUrl}');
      final report = result.report;
      if (report != null) {
        print('Down: ${report.customerInternetSpeed?.networkSpeedDown} Mbps');
        for (final alert in report.alerts ?? []) {
          switch (alert.type) {
            case AlertType.oldRouter: /* localise your own copy */
            case AlertType.unknown:   /* forward-compatible fallback */
            default: break;
          }
        }
      }
    case ScanFailed(:final error):
      print('Failed: ${error.message}');
    case ScanStarted():
    case ScanDataPersisted():
    case ScanCanceled():
  }
});

await sdk.configure(ScanConfig(apiKey: 'your-key'));
await sdk.startScan();
```

## Reading the report

`result.reportUrl` opens the hosted report and is always present.
`result.report` is the same data as structured Dart objects, for building your
own UI. It is null on backends predating the payload.

### Gotchas

| Shape | Where | Note |
|---|---|---|
| Single-entry map, not a struct | `customerInternetSpeed.connectionQuality` | `{"good": "green"}` — read the first entry |
| ...but this one **is** a struct | `connectionQualityColor` on devices and DNS results | `{quality, color}` |
| Different field names | `alerts` vs `actions` | `alert_*` vs `action_*`; not interchangeable |
| Null means "not detected" | `networkTopology.doubleNatDetected` | The key is absent, not false |
| `"Enabled"` / `"Disabled"` strings | `firewall`, `multicast`, `clientIsolation` | Not booleans |
| String, not int | `channelCongestion.index` | |

Branch on `alert.type` / `action.type`, never on `alertValue` / `actionValue` —
those are display strings, sometimes templated at runtime, and are not stable
identifiers. Unrecognised values resolve to `unknown` rather than throwing.

## Bundled AARs

| Artifact | Maven coordinates | Source |
|----------|-------------------|--------|
| `tools-1.1.aar` | `org.bitbucket.creativeadvtech:tools:1.1` | `scanmynet-android` `:tools` module |
| `traceroute-1.0.0.aar` | `com.synaptic-tools:traceroute:1.0.0` | `com.synaptic-tools` vendor |

AARs are served from `android/local-maven-repo/` using standard Maven layout.
When a new version is released, run `./gradlew :tools:assembleRelease` in
`scanmynet-android` and replace the AAR file.
See [CONTRIBUTING.md](CONTRIBUTING.md) for the full update guide.

## Bundled iOS framework

| Artifact | Vendored at | Source |
|----------|-------------|--------|
| `ScanMyNet.xcframework` | `ios/ScanMyNet.xcframework` | `scanmynet-ios` `Production` scheme |

Rebuilt from the `scanmynet-ios` repo via `xcodebuild archive` (device +
simulator) and `xcodebuild -create-xcframework`. See
[CONTRIBUTING.md](CONTRIBUTING.md) for the exact commands. Its third-party Swift
dependencies are resolved from CocoaPods trunk — see [iOS setup](#ios).

## See also

- [CONTRIBUTING.md](CONTRIBUTING.md) — developer setup and AAR update guide
