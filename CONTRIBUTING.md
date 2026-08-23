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

The private AARs live in `android/local-maven-repo/` in standard Maven layout —
not just the `.aar` files but a `.pom`, a `.module`, four checksums per file,
and a `maven-metadata.xml` listing every version. Hand-copying an AAR leaves
all of those stale, and Gradle then either rejects the artifact or silently
resolves the previous version.

So publish into this directory rather than copying into it. `:tools` has a
`bundled` Maven repository for exactly that:

```bash
# In the scanmynet-android repo, after bumping `version` in tools/build.gradle:
./gradlew :tools:publishReleasePublicationToBundledRepository     -PbundledRepoDir=/absolute/path/to/scanmynet_sdk/android/local-maven-repo
```

That writes the new version directory, its checksums, and an updated
`maven-metadata.xml`. Then point the plugin at it:

```kotlin
// android/build.gradle.kts
implementation("org.bitbucket.creativeadvtech:tools:X.Y")
```

Delete the superseded version directory in the same commit — the plugin
resolves exactly one version, and every other one is dead weight shipped to
every consumer. Re-run the publish afterwards so `maven-metadata.xml` stops
advertising versions that are no longer present.

Finally, rebuild a consuming app (`flutter build apk --debug`) before
committing. Resolution failures here surface in the consumer, not in this
package's own analysis.

### `traceroute`

`com.synaptic-tools:traceroute` is a transitive dependency declared in the
`tools` POM, so the publish above brings the right version across on its own.

It is **not** the upstream JitPack artifact. Upstream 1.0.0 ships `.so` files
aligned to 4 KB pages, which Android 15+ cannot load on a 16 KB-page device, so
`scanmynet-android` vendors a rebuilt 1.0.1 in its own `local-maven-repo/`.
See that directory's `README.md` for the source commit, the build flags, and
how to reproduce it — that is the only place the rebuild is documented.

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

## Releasing to pub.dev

pub.dev freezes each version's `pubspec.yaml` and `README.md` at upload time and
renders the README verbatim as the package landing page. Nothing about a
published version can be edited afterwards, and a version number can never be
reused — a mistake costs a whole release. Work through this list before
publishing:

1. Bump `version` in `pubspec.yaml`.
2. Bump the install snippet in `README.md` under **Install** to match. It is a
   hand-written literal, so it does not follow the version on its own — it sat
   at `^1.0.2` for three releases because of this.
3. Add a `CHANGELOG.md` entry under the new heading. Do **not** edit entries for
   versions already on pub.dev: what is published there is frozen, so an edit
   here makes the two disagree about what shipped.
4. `flutter pub publish --dry-run` — expect `Package has 0 warnings`. It warns
   about an unclean working tree, so commit first.
5. Merge to `main`, then publish from `main`:

   ```bash
   git checkout main && git pull
   flutter pub publish
   git tag -a v<version> -m "scanmynet_sdk <version>" && git push origin v<version>
   ```

The GitHub mirror updates itself — see `bitbucket-pipelines.yml`.
