# scanmynet_sdk

Flutter plugin for the ScanMyNet network diagnostics SDK — wraps the native
Android **and iOS** SDKs to run a full home-network scan (speed test, DNS,
traceroute, device discovery) and submit results as a report to the ScanMyNet
backend.

## Install

```yaml
dependencies:
  scanmynet_sdk: ^1.3.0
```

## Prerequisites

| Tool | Version |
|------|---------|
| Flutter / Dart | ≥ 3.3.0 / ^3.12.0 |
| Android SDK | compileSdk 36, minSdk 24 |
| Java | 17 |
| iOS / CocoaPods | deployment target ≥ 15.0 |
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

**3. Decide what Android may back up.** Recommended, not required:

```xml
<application android:allowBackup="false" ... >
```

With backup on — which is the platform default — `adb backup` and Auto Backup
copy your app's private data directory off the device. That matters here because
whatever you persist alongside a scan goes with it: your API key, if you cache
it, and any report data you keep locally.

The plugin deliberately does **not** set this in its own manifest. A library's
value wins the merge for any app that states no value of its own, so setting it
here would make the decision for every app embedding the SDK — including apps
that legitimately want backup. If your app does want it, prefer
`android:dataExtractionRules` (API 31+) or `android:fullBackupContent` to exclude
the files the SDK writes, and note that those work by exclusion: anything added
later is backed up by default.

### iOS

The native iOS SDK ships as the bundled `ios/ScanMyNet.xcframework` (the
counterpart of the Android AARs). Its three third-party Swift dependencies
(`Alamofire`, `XMLCoder`, `BlueSocket`) are declared in
`ios/scanmynet_sdk.podspec` and resolved from the public CocoaPods trunk during
`pod install`.

> **Upgrading from 1.1.11 or earlier:** the SDK now needs **iOS 15**. Set
> `platform :ios, '15.0'` in your app's `ios/Podfile` and raise the Runner
> target's deployment target to match — with either left at 13.0, `pod install`
> fails with "required a higher minimum deployment target".

> **Upgrading from 1.1.5 or earlier:** `NDT7` is no longer a dependency — run
> `pod install` and drop it from your `post_install` list if you named it there.

> **Required:** the framework is compiled with library evolution, so its Swift
> dependencies must be rebuilt the same way in the host app — otherwise the app
> crashes at launch with a dyld `Symbol not found` error. Add this to your app's
> `ios/Podfile` `post_install` (already present in `example/ios/Podfile`):
>
> ```ruby
> post_install do |installer|
>   installer.pods_project.targets.each do |target|
>     flutter_additional_ios_build_settings(target)
>     if %w[Alamofire XMLCoder BlueSocket].include?(target.name)
>       target.build_configurations.each do |config|
>         config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
>       end
>     end
>   end
> end
> ```

### Permissions (iOS)

Declare these in your app's `Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Location is used to read WiFi and router details during a network scan.</string>
<key>NSLocalNetworkUsageDescription</key>
<string>Local network access is used to discover devices and your router during a network scan.</string>
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsLocalNetworking</key>
  <true/>
</dict>
<key>NSBonjourServices</key>
<array>
  <string>_workstation._tcp</string>
  <string>_companion-link._tcp</string>
  <string>_device-info._tcp</string>
  <string>_airplay._tcp</string>
  <string>_raop._tcp</string>
  <string>_homekit._tcp</string>
  <string>_hap._tcp</string>
  <string>_googlecast._tcp</string>
  <string>_ipp._tcp</string>
  <string>_printer._tcp</string>
  <string>_smb._tcp</string>
  <string>_ssh._tcp</string>
  <string>_http._tcp</string>
</array>
```

And two entitlements, in `ios/Runner/Runner.entitlements`:

```xml
<key>com.apple.developer.networking.multicast</key>
<true/>
<key>com.apple.developer.networking.wifi-info</key>
<true/>
```

Adding that file through Xcode's **Signing & Capabilities** tab sets the
target's `CODE_SIGN_ENTITLEMENTS` for you. `example/ios/Runner` has both files
if you want to copy them.

| Missing | What breaks |
|---|---|
| `NSLocationWhenInUseUsageDescription` | report's `userWifiNetwork` (`user_wifi_network`) is empty |
| `NSLocalNetworkUsageDescription` | no local-network prompt, so nothing on the LAN is reachable |
| `NSBonjourServices` | Bonjour browsing returns zero devices, with no error |
| `NSAllowsLocalNetworking` | the router is found but its description can't be read, so no make/model |
| `com.apple.developer.networking.multicast` | router (SSDP/UPnP) discovery finds nothing |
| `com.apple.developer.networking.wifi-info` | SSID/BSSID come back empty |

Writing the two entitlements into the file is only half of it — each also has to
be enabled on your App ID in the Apple Developer portal, or signing fails:

| Entitlement | How to enable it |
|---|---|
| `wifi-info` | Self-serve. Tick **Access WiFi Information** on the App ID. |
| `multicast` | [Request form](https://developer.apple.com/contact/request/networking-multicast). Free, takes a few days. |

Regenerate your provisioning profile afterwards — an existing one does not pick
up newly granted entitlements on its own.

Three more things worth knowing before you file a bug about missing router
details:

Entitlements are applied at code-signing time, so they only exist in a **signed**
build. An unsigned `.ipa` carries none of them, whoever re-signs it afterwards.

Only *raw* multicast — the SSDP search that finds your router — needs the
multicast entitlement. Bonjour device discovery needs `NSBonjourServices` and
the local-network permission, but not the entitlement, so the two fail
independently.

**The first scan after a user grants local network access may not find the
router.** iOS answers that prompt asynchronously, and the SSDP search is already
under way and refused by the time they tap Allow; it is not retried. Call
`configure()` early — at app start, or when the scan screen opens — rather than
immediately before `startScan()`, so the prompt has been dealt with before a
scan begins. A scan that hits this still completes; the report just has no
router section.

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
      // result.reportUrl  -> hosted web report (always present)
      // result.report     -> typed ReportData for your own UI (see below)
      // result.reportId   -> correlate the scan without parsing reportUrl's JWT
      // result.customerId -> the subscriber key the report was filed under
    case ScanFailed(:final error):
      // error.kind (perStep | submission | canceled | notAlWatani), error.message
    case ScanDataPersisted():
      // Android-only debug snapshot; most apps can ignore it
    case ScanCanceled():
      // cancel() completed
  }
});

// 2. Configure (choose the backend with `environment`), then start.
await sdk.configure(ScanConfig(
  apiKey: 'your-key',
  userKey: 'your-customer-key', // reports are filed and searched by this
  appName: 'Your App',          // shown on the report as the originating app
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

### Scans on the wrong network

A scan started on 4G, or on a network that is not the provider's own, used to
hang or come back empty. Before any measurement the SDK now checks that the
device is on Wi-Fi and asks the backend whether that Wi-Fi is the provider's
network. If not, the scan stops at once with a `ScanFailed` whose `error.kind` is
`ScanErrorKind.notAlWatani`: nothing is measured, nothing is submitted, and no
`ScanProgressed` events fire (`ScanStarted` still arrives first).

`error.message` is an English customer message; localise it in your app by
switching on the kind:

```dart
case ScanFailed(:final error) when error.kind == ScanErrorKind.notAlWatani:
  // error.message is English: it asks the user to connect to the provider's
  // Wi-Fi network and run the test again. Show your own translation here.
  showWifiHelp(context); // a statement: an empty case falls through in Dart 3
```

The check only refuses on positive evidence. If the backend errors, is
unreachable, does not answer within 5 seconds, or has not been given the
provider's address ranges (or is still in its default observe-only mode), the
scan **proceeds**: a customer is never turned away because of our own outage. `notAlWatani` is terminal; the user fixes their network and
calls `startScan()` again.

What counts as "on Wi-Fi" is the device's *default* network. So a phone whose
Wi-Fi has lost its internet and fell back to mobile data is refused (a scan
would otherwise measure mobile data and file it as the customer's line); wired
Ethernet counts as "not Wi-Fi", which matters for an iOS Simulator on a wired
Mac; and an Android emulator image that exposes only a cellular network is
refused, so use one with Wi-Fi. A VPN makes the backend see the VPN's address,
so with the server verdict enforced a VPN user is refused as `notAlWatani`.

`ScanConfig` fields worth setting explicitly:

| Field | Purpose |
|---|---|
| `apiKey` | **Mandatory.** Authenticates the submission; a missing or wrong key is a 401 |
| `userKey` | The customer key. Reports are filed and searched by it — set it, or you will not find your scans |
| `appName` | The embedding app's name, shown on the report as its origin |
| `requestKey` | Deprecated alias for `userKey`, read only when `userKey` is unset |
| `packageSpeedMbps` | Optional. The customer's subscribed speed in Mbps, so the download speed is rated against what they pay for (below). A value that cannot be a speed is dropped, not sent |
| `packageKey` | Optional. The provider's code for the customer's subscription package: the backend rates the download speed with that package's own limits (below). A blank key is not sent |

`packageSpeedMbps` lets the report judge a result by the package: Good from 80% of
it, Moderate from 50%, Poor below. Leave it unset and the download speed is rated on
fixed bands (Good above 30 Mbps, Moderate 15 to 30, Poor below 15), exactly as for
an app that never heard of the field. The native SDKs drop zero, negative, `NaN`,
infinite and above-100,000 values instead of sending them, because the backend
refuses a report carrying one and the whole scan would be lost. It is read once, at
`configure()`; call `configure()` again to change it.

`packageKey` is the provider's code for the customer's subscription package. The
backend looks the package up and rates the download speed with that package's own
limits, so the same speed can be Good on one package and Poor on another, and the
report names the package. It is optional: without a key, or with one the backend does
not know, the package speed above is used if set, then the fixed bands. The key must
match the provider's code exactly, capital letters and symbols included. It is
trimmed, and a blank key is not sent. Like `packageSpeedMbps` it is read once, at
`configure()`.

> **Before 1.1.11, `userKey` reached Android only.** iOS read `requestKey`
> instead, and where that was unset the native SDK substituted a built-in
> fallback key of its own — so iOS reports were filed against a different
> customer and could not be found, while the submission still returned 200 with
> a report id and nothing looked wrong. From 1.1.11 both platforms read
> `userKey` first and fall back to `requestKey`, so either name works on both.
> `appName` reached Android only over the same period; iOS reported every scan
> as coming from an app called `ScanMyNet`.

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

**Where the customer's wording lives.** The sentences a customer reads — what a
speed means, what Good / Moderate / Poor stand for, in English and Arabic — are
written in the hosted web report (`reportUrl`), not in this SDK. `result.report`
carries numbers and ratings (`customerInternetSpeed.connectionQuality`,
`connectionQualityColor`), so an app that draws its own UI has to supply its own
words; one that opens `reportUrl` gets them, and any change to them, with no SDK
upgrade.

`result.reportId` and `result.customerId` come alongside, for correlating a scan
against your own records without parsing the JWT in `reportUrl`. Both are
populated on Android and on iOS from 1.1.6 — earlier iOS releases left them null.

`ReportData` fields fill in the same way over time. `customerRouterDetails`,
`routerMacAddress` and `networkUsageDown` / `networkUsageUp` were Android-only
and arrived null on iOS until 1.1.7; the router section of a report was empty on
iOS for the same reason, because the backend only returns it once the router's
MAC is known. `localConnectedDevices[].manufacturer` read "unknown" for every
device on iOS until 1.1.8.

`ReportData` has 15 optional sections. **Every field is nullable** — read
defensively with `?.` and treat `null` as "not measured":

> **Speed figures are comparable across platforms.** Both SDKs measure against
> `speed.cloudflare.com` with the same plan: payloads grow from 100 KB until a
> request takes a second, each direction stops at 150 MB or 45 s, and the figure
> is the 90th percentile of the per-request rates. A slow connection therefore
> finishes the speed test in about a minute and a half instead of stalling the
> scan.
>
> **Readings from 1.2.0 on are not comparable with earlier ones.** They are in
> decimal Mbps; earlier releases reported Mibit/s, which reads 4.86% low, and
> measured a single large download against another server. Don't trend a
> customer's speed across the upgrade.
>
> **Upload figures are comparable from 1.1.11.** Before that, iOS read 1–3 Mbps
> on every connection however fast it was — one report read 131 down and 2.4 up,
> where Android on the same network matched a reference speed test. iOS uploaded
> through URLSession, which negotiates HTTP/2, and the speed-test host never
> raises the HTTP/2 stream window from its 65535-byte default: the transfer ran
> at window ÷ round-trip rather than at the line rate, so the figure barely moved
> with the connection and fell the further a user was from the server. **Discard
> iOS upload readings from 1.1.7–1.1.10**; downloads over the same period were
> unaffected and remain comparable.

| Section | Type | Contains |
|---|---|---|
| `customerInternetSpeed` | `InternetSpeed?` | download / upload Mbps, link speed, segments |
| `localConnectedDevices` | `List<LocalConnectedDevice>?` | discovered devices — name, IP, MAC, manufacturer, ping |
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

### What iOS cannot measure

Some sections are thinner on iOS, permanently. Apple exposes no API to an app
for scanning nearby Wi-Fi networks, reading the link layer, or inspecting the
DHCP lease, so these arrive null or near-empty on iOS however healthy the
network is. Treat them as "not available on this platform", not as a failed
scan:

| Field | iOS | Why |
|---|---|---|
| `networkCongestion` — channel congestion, surrounding networks | not measured | needs a Wi-Fi scan; no public API |
| `userWifiNetwork` — frequency, channel, encryption, signal strength | SSID, BSSID and IP only | same |
| `customerRouterDetails.protocols` (e.g. 802.11ax) | not measured | no Wi-Fi standard API |
| link speed on `customerInternetSpeed` | not measured | no negotiated-link-speed API |
| `ip_assigned_via_dhcp` | not measured | no DHCP lease API |

Everything else — speed, LAN devices, ping, jitter, packet loss, traceroute,
DNS, port checks, router identity — is measured the same way on both platforms
and can be compared directly, with the upload caveat noted above.

### Gotchas

| Shape | Where | Note |
|---|---|---|
| Single-entry map, not a struct | `customerInternetSpeed.connectionQuality` | `{"good": "green"}` — read the first entry. Rated by the backend, so an SDK upgrade is not needed to get a rule change: Good above 30 Mbps, Moderate 15 to 30, Poor below 15 (was 5 and 7.5), or by share of the package when `ScanConfig.packageSpeedMbps` is set. A report stored earlier keeps its old label |
| ...but this one **is** a struct | `connectionQualityColor` on devices and DNS results | `{quality, color}`. On a device it is the worse of packet loss and average ping (ping counts only when `numPacketsSent` > 1), decided by the backend: no SDK upgrade is needed to get it. On a DNS result it follows the thresholds the admin configures for that server in the agent portal (packet-loss limits are counts of the 30 packets sent, not percentages), and `layerRanking` is the admin's layer for it (0 router, 1 or 2; 2 when unconfigured), not a local / external flag |
| Different field names | `alerts` vs `actions` | `alert_*` vs `action_*`; not interchangeable |
| Not surfaced | `ping_quality`, `packet_loss_quality` on each connection-quality entry | The backend rates the router's and each DNS server's ping and packet loss (excellent / good / moderate / poor, or null when it cannot judge) for the web report. `DnsQuality` is unchanged: it still carries only `connectionQualityColor`, which follows the admin thresholds |
| Null means "not detected" | `networkTopology.doubleNatDetected` | The key is absent, not false |
| `"Enabled"` / `"Disabled"` strings | `firewall`, `multicast`, `clientIsolation` | Not booleans |
| String, not int | `channelCongestion.index` | |
| UTC, no zone suffix | `sdkDetails.start` | `yyyy-MM-dd HH:mm:ss`, 24-hour; convert before showing it. Reports from earlier SDKs used a 12-hour clock with no AM/PM, so an afternoon scan reads 12 hours early |

Branch on `alert.type` / `action.type`, never on `alertValue` / `actionValue` —
those are display strings, sometimes templated at runtime, and are not stable
identifiers. Unrecognised values resolve to `unknown` rather than throwing.

## Bundled AARs

| Artifact | Maven coordinates | Source |
|----------|-------------------|--------|
| `tools-1.9.aar` | `org.bitbucket.creativeadvtech:tools:1.9` | `scanmynet-android` `:tools` module |
| `traceroute-1.0.1.aar` | `com.synaptic-tools:traceroute:1.0.1` | rebuilt from upstream sources for 16 KB page alignment |

AARs are served from `android/local-maven-repo/` using standard Maven layout.
A new version is *published* into that directory rather than copied over it, so
that checksums and `maven-metadata.xml` stay consistent — see
[CONTRIBUTING.md](CONTRIBUTING.md) for the command.

## Bundled iOS framework

| Artifact | Vendored at | Source |
|----------|-------------|--------|
| `ScanMyNet.xcframework` | `ios/ScanMyNet.xcframework` | `scanmynet-ios` `Production` scheme (v1.2.0) |

Rebuilt from the `scanmynet-ios` repo via `xcodebuild archive` (device +
simulator) and `xcodebuild -create-xcframework`. See
[CONTRIBUTING.md](CONTRIBUTING.md) for the exact commands. Its third-party Swift
dependencies are resolved from CocoaPods trunk — see [iOS setup](#ios).

## See also

- [CONTRIBUTING.md](CONTRIBUTING.md) — developer setup and AAR update guide
