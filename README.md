# scanmynet_sdk

Flutter plugin for the ScanMyNet network diagnostics SDK — wraps the native
Android **and iOS** SDKs to run a full home-network scan (speed test, DNS,
traceroute, device discovery) and submit results as a report to the ScanMyNet
backend.

## Install

```yaml
dependencies:
  scanmynet_sdk: ^1.1.2
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

The private native AARs are bundled in
[android/local-maven-repo/](android/local-maven-repo/). The plugin registers that
repository with your build automatically (along with JitPack, which serves a
transitive dependency of the native SDK) — **no Gradle changes needed on your
side**. Your app must be on `minSdk 24` or higher.

Two things you do have to add to your app:

**1. Location permissions.** Declare them in
`android/app/src/main/AndroidManifest.xml` and request `ACCESS_FINE_LOCATION` at
runtime (e.g. with `permission_handler`):

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

Without location **granted at runtime**, Android anonymises Wi-Fi data and the
report's `userWifiNetwork` section comes back with placeholder values.

**2. Cleartext HTTP, for router identification.** The UPnP/SSDP step fetches the
router's device-description XML over plain HTTP (e.g.
`http://192.168.0.1/rootDesc.xml`). Android 9+ blocks cleartext by default,
which silently leaves `customerRouterDetails.make`/`model` as "Unknown" (SSDP
itself is raw UDP and still works, so the router IP appears but its identity does
not).

Create `android/app/src/main/res/xml/network_security_config.xml`:

```xml
<network-security-config>
    <base-config cleartextTrafficPermitted="true">
        <trust-anchors><certificates src="system" /></trust-anchors>
    </base-config>
</network-security-config>
```

and reference it from your `<application>` tag:

```xml
<application android:networkSecurityConfig="@xml/network_security_config" ... >
```

Cleartext is *permitted*, not forced — the HTTPS report backend still uses TLS.

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

## Usage

The plugin exposes a single class, `ScanmynetSdk`. Commands flow Dart → native
(`configure` / `startScan` / `cancel`); lifecycle updates come back as a
broadcast stream of `ScanEvent`s. A typical flow:

```dart
final sdk = ScanmynetSdk();

// 1. Subscribe BEFORE starting, so you catch every event.
final sub = sdk.events.listen((event) {
  switch (event) {
    case ScanStarted():
      // the scan has begun
    case ScanProgressed(:final progress):
      // progress.percent (0..100); progress.label / progress.currentStep
    case ScanCompleted(:final result):
      // result.reportUrl -> hosted web report (always present)
      // result.report    -> typed ReportData for your own UI (see below)
    case ScanFailed(:final error):
      // error.kind (perStep | submission | canceled), error.message
    case ScanDataPersisted():
      // Android-only debug snapshot; most apps can ignore it
    case ScanCanceled():
      // cancel() completed
  }
});

// 2. Configure (choose the backend with `environment`), then start.
await sdk.configure(ScanConfig(
  apiKey: 'your-key',
  environment: ScanEnvironment.production, // .dev | .staging | .production | .custom
));
await sdk.startScan();

// 3. Optionally cancel an in-flight scan (iOS; best-effort no-op on Android).
await sdk.cancel();

// 4. When you're done with the SDK, release the native handler.
await sub.cancel();
sdk.dispose();
```

| Member | Purpose |
|---|---|
| `sdk.events` | broadcast `Stream<ScanEvent>` — the six lifecycle events above |
| `sdk.progress` | convenience `Stream<ScanProgress>` if you only want progress |
| `configure(ScanConfig)` | set API key + `environment`; call before `startScan` |
| `startScan()` | begin a scan; results arrive via `events` |
| `cancel()` | cancel an in-flight scan (iOS) |
| `dispose()` | detach the native handler and close the streams |

### Pointing the SDK at your own backend

`ScanEnvironment.custom` targets a self-hosted ScanMyNet deployment instead of
ours — for operators who run the backend on their own infrastructure:

```dart
await sdk.configure(ScanConfig(
  apiKey: 'your-key',
  environment: ScanEnvironment.custom,
  customBaseUrl: 'https://smn.example.com/',
));
```

`customBaseUrl` is the **server root**, not an endpoint. The SDK still appends
its own paths (`/api/v1/report/`, `/api/v1/scan_configs/dns_config`), so your
deployment must expose the same endpoint names ours does. The trailing slash is
optional.

The shareable report link is assembled client-side from a separate viewer root,
because the backend returns a report's `verification_token` but not a usable
link. It defaults to `customBaseUrl`; set `customFrontendUrl` when a different
host serves the viewer:

```dart
await sdk.configure(ScanConfig(
  apiKey: 'your-key',
  environment: ScanEnvironment.custom,
  customBaseUrl: 'https://api.example.com/',
  customFrontendUrl: 'https://portal.example.com/',   // optional
));
```

Both fields are ignored unless `environment` is `.custom`, and `configure`
throws `ArgumentError` if `.custom` is selected without a `customBaseUrl`.

## Building your own UI from the report

Every completed scan returns the report **two ways**:

- **`result.reportUrl`** — the hosted web report, always present. Open it in a
  browser or `WebView` for a zero-effort display.
- **`result.report`** — the *same data as typed Dart objects* (`ReportData`), so
  you can render it however you like. Null only on backends predating the payload.

`ReportData` has 15 optional sections. **Every field is nullable** — read
defensively with `?.` and treat `null` as "not measured":

| Section | Type | Contains |
|---|---|---|
| `customerInternetSpeed` | `InternetSpeed?` | download / upload Mbps, link speed, segments |
| `localConnectedDevices` | `List<LocalConnectedDevice>?` | discovered devices — name, IP, MAC, ping |
| `userWifiNetwork` | `WifiNetworkResult?` | SSID, BSSID, frequency, channel, signal |
| `customerRouterDetails` | `CustomerRouterDetails?` | make / model, encryption, mesh |
| `networkTopology` | `NetworkTopology?` | other routers, double-NAT detection |
| `networkCongestion` | `NetworkCongestion?` | channel congestion, surrounding networks |
| `basicConnectivity` | `BasicConnectivity?` | server / port / DNS checks, firewall |
| `connectionQuality` | `List<DnsQuality>?` | per-DNS ping / jitter quality |
| `traceroute` | `List<TracerouteEntry>?` | hops per destination |
| `alerts` / `actions` | `List<ReportAlert>?` / `List<ReportAction>?` | issues found + recommended fixes |
| `customerDetails`, `sdkDetails`, `routerUsageDuringScan`, `incompleteAnalysis` | | metadata + reliability flag |

Read whichever sections your UI needs:

```dart
final report = result.report;
if (report != null) {
  final downMbps = report.customerInternetSpeed?.networkSpeedDown; // double?
  final deviceCount = report.localConnectedDevices?.length ?? 0;   // int
  final ssid = report.userWifiNetwork?.ssid;                       // String?
  final router = report.customerRouterDetails;                     // object?

  for (final device in report.localConnectedDevices ?? const []) {
    print('${device.deviceName} @ ${device.deviceIp}');
  }

  for (final alert in report.alerts ?? const []) {
    switch (alert.type) {            // typed enum — never throws
      case AlertType.oldRouter:      // show your own localized copy
      case AlertType.unknown:        // forward-compatible fallback
      default: break;
    }
  }
}
```

> **Complete, runnable example:** the example app renders a custom report card
> at [`example/lib/ui/features/scan/views/widgets/report_summary_card.dart`](example/lib/ui/features/scan/views/widgets/report_summary_card.dart)
> — it pulls speed, device count, Wi-Fi, router, and alerts out of `ReportData`.
> Copy it as a starting point for your own UI.

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
| `tools-1.4.aar` | `org.bitbucket.creativeadvtech:tools:1.4` | `scanmynet-android` `:tools` module |
| `traceroute-1.0.1.aar` | `com.synaptic-tools:traceroute:1.0.1` | rebuilt from upstream sources for 16 KB page alignment |

AARs are served from `android/local-maven-repo/` using standard Maven layout.
A new version is *published* into that directory rather than copied over it, so
that checksums and `maven-metadata.xml` stay consistent — see
[CONTRIBUTING.md](CONTRIBUTING.md) for the command.

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
