# scanmynet_sdk

Flutter plugin wrapping the ScanMyNet native Android **and iOS** SDKs. Performs
Wi-Fi network scans (speed test, DNS, traceroute, device discovery) and submits
results as a report to the ScanMyNet backend.

## Prerequisites

| Tool | Version |
|------|---------|
| Flutter / Dart | ≥ 3.3.0 / ^3.12.0 |
| Android SDK | compileSdk 36, minSdk 24 |
| Java | 17 |
| iOS / CocoaPods | deployment target ≥ 13.0 |
| Xcode | 15+ |
| FVM (recommended) | any |

## Quick start

No extra setup required — the private native AARs are bundled in
[android/local-maven-repo/](android/local-maven-repo/) and resolved automatically at build time.

```bash
cd example
fvm flutter pub get
fvm flutter build apk --release "--dart-define=SMN_API_KEY=<your-api-key>"
```

The signed APK is written to:
```
example/build/app/outputs/flutter-apk/app-release.apk
```

## iOS setup

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

The example app also declares `NSLocationWhenInUseUsageDescription` and
`NSLocalNetworkUsageDescription` in its `Info.plist` — both are required at
runtime for Wi-Fi/router details and LAN/SSDP device discovery.

```bash
cd example
fvm flutter build ios --release "--dart-define=SMN_API_KEY=<your-api-key>"
```

## Environment variables / dart-defines

| Key | Required | Description |
|-----|----------|-------------|
| `SMN_API_KEY` | Yes | API key sent as `api-key` header to the backend |

Pass via `--dart-define=SMN_API_KEY=...` — **never** hardcode in source.

## Bundled AARs

| Artifact | Maven coordinates | Source |
|----------|-------------------|--------|
| `tools-1.0.aar` | `org.bitbucket.creativeadvtech:tools:1.0` | `scanmynet-android` `:tools` module |
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
dependencies are resolved from CocoaPods trunk — see [iOS setup](#ios-setup).

## See also

- [CONTRIBUTING.md](CONTRIBUTING.md) — developer setup and AAR update guide
