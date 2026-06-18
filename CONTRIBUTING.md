# Contributing to scanmynet_sdk

## Repository layout

```
scanmynet_sdk/
├── android/local-maven-repo/   ← private AARs as a local Maven repo
├── android/build.gradle.kts
├── ios/ScanMyNet.xcframework/   ← prebuilt native iOS SDK (vendored binary)
├── ios/scanmynet_sdk.podspec    ← vendors the xcframework + its CocoaPods deps
├── lib/                        ← Dart/Flutter plugin code
├── pigeons/                    ← Pigeon platform channel definitions
└── example/                    ← runnable demo app
```

The plugin is self-contained. New developers only need this one repo.

The iOS integration uses CocoaPods only (no Swift Package Manager). The native
SDK ships as the bundled `ios/ScanMyNet.xcframework` — the iOS counterpart of the
Android `tools` AAR.

## First-time setup

```bash
git clone git@bitbucket.org:creativeadvtech/scanmynet_sdk.git
cd scanmynet_sdk
fvm flutter pub get
```

## Building the example app

```bash
cd example
fvm flutter build apk --release "--dart-define=SMN_API_KEY=<api-key>"
```

## Updating the bundled AARs

The private AARs live in `android/local-maven-repo/` in standard Maven layout.
They must be updated manually whenever a new version of the native `tools` SDK
is released.

### Update `tools-X.Y.aar`

```bash
# In the scanmynet-android repo:
./gradlew :tools:assembleRelease
# Copy AAR to the local Maven repo:
cp tools/build/outputs/aar/tools-release.aar \
   ../scanmynet_sdk/android/local-maven-repo/org/bitbucket/creativeadvtech/tools/1.0/tools-1.0.aar
```

If the version number changes, create a new Maven directory for the new version,
copy the AAR and POM there, and update the version string in
`android/build.gradle.kts`.

### Update `traceroute-X.Y.Z.aar`

The `traceroute` AAR is a transitive dependency resolved from the `tools` POM —
you normally do not need to update it independently. If a new version is required,
place it at:
```
android/local-maven-repo/com/synaptic-tools/traceroute/<version>/traceroute-<version>.aar
```
and add a matching `.pom` file alongside it.

## Updating the bundled iOS framework

Unlike the self-contained Android AARs, the iOS SDK is **not** standalone — it
links four third-party frameworks (`Alamofire`, `XMLCoder`, `BlueSocket`,
`NDT7`). These are declared as `s.dependency` lines in `ios/scanmynet_sdk.podspec`
and resolved from the public CocoaPods trunk during `pod install`, so they are
**not** bundled. Only the proprietary `ScanMyNet.xcframework` is vendored.

To rebuild `ios/ScanMyNet.xcframework` from the `scanmynet-ios` repo:

```bash
# In the scanmynet-ios repo (which has its Pods installed via `pod install`):
xcodebuild archive -workspace ScanMyNet.xcworkspace -scheme Production \
  -configuration 'Production Release' -destination 'generic/platform=iOS' \
  -archivePath build/ScanMyNet-iphoneos \
  SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES

xcodebuild archive -workspace ScanMyNet.xcworkspace -scheme Production \
  -configuration 'Production Release' -destination 'generic/platform=iOS Simulator' \
  -archivePath build/ScanMyNet-iphonesimulator \
  SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES

xcodebuild -create-xcframework \
  -framework build/ScanMyNet-iphoneos.xcarchive/Products/Library/Frameworks/ScanMyNet.framework \
  -debug-symbols "$PWD/build/ScanMyNet-iphoneos.xcarchive/dSYMs/ScanMyNet.framework.dSYM" \
  -framework build/ScanMyNet-iphonesimulator.xcarchive/Products/Library/Frameworks/ScanMyNet.framework \
  -debug-symbols "$PWD/build/ScanMyNet-iphonesimulator.xcarchive/dSYMs/ScanMyNet.framework.dSYM" \
  -output ../scanmynet_sdk/ios/ScanMyNet.xcframework
```

If the SDK's own dependency set changes, update the `s.dependency` lines in
`ios/scanmynet_sdk.podspec` to match `scanmynet-ios/Podfile.lock`.

### Library evolution (important)

The framework is archived with `BUILD_LIBRARY_FOR_DISTRIBUTION=YES`, so it links
against the **resilient** ABI of its Swift dependencies. The host app must
therefore rebuild those same pods with library evolution, or the app crashes at
launch with a dyld `Symbol not found` error (e.g. a missing Alamofire witness
symbol). This is enforced by the `post_install` hook in `example/ios/Podfile`,
which sets `BUILD_LIBRARY_FOR_DISTRIBUTION=YES` on `Alamofire`, `XMLCoder`,
`BlueSocket`, and `NDT7`. Any app consuming this plugin needs the same hook — see
the [iOS setup section in the README](README.md#ios-setup).

Dependency versions are pinned **exactly** in the podspec because a precompiled
Swift binary is bound to the exact symbol tables it was built against — even a
patch bump (e.g. Alamofire 5.11.1 → 5.11.2) can drop a symbol and crash at
launch.

## Running Pigeon (platform channel code generation)

If you change `pigeons/messages.dart`, regenerate the platform channel glue:

```bash
fvm dart run pigeon --input pigeons/messages.dart
```

This updates:
- `lib/src/messages.g.dart`
- `android/src/main/kotlin/.../Messages.g.kt`
- `ios/scanmynet_sdk/Sources/scanmynet_sdk/Messages.g.swift`

## Adding a new transitive dependency to tools

When a new dependency is added to `tools/build.gradle` in `scanmynet-android`,
it must also be added to `android/build.gradle.kts` here (since flat AAR
references don't carry a POM). Add it under the `// Public transitive deps`
section matching its original scope (`api` → compile scope, `implementation` →
runtime scope).
