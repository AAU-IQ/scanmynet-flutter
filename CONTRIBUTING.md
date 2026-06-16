# Contributing to scanmynet_sdk

## Repository layout

```
scanmynet_sdk/
├── android/local-maven-repo/   ← private AARs as a local Maven repo
├── android/build.gradle.kts
├── lib/                        ← Dart/Flutter plugin code
├── pigeons/                    ← Pigeon platform channel definitions
└── example/                    ← runnable demo app
```

The plugin is self-contained. New developers only need this one repo.

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

## Running Pigeon (platform channel code generation)

If you change `pigeons/messages.dart`, regenerate the platform channel glue:

```bash
fvm dart run pigeon --input pigeons/messages.dart
```

This updates:
- `lib/src/messages.g.dart`
- `android/src/main/kotlin/.../Messages.g.kt`
- `ios/Classes/messages.g.swift`

## Adding a new transitive dependency to tools

When a new dependency is added to `tools/build.gradle` in `scanmynet-android`,
it must also be added to `android/build.gradle.kts` here (since flat AAR
references don't carry a POM). Add it under the `// Public transitive deps`
section matching its original scope (`api` → compile scope, `implementation` →
runtime scope).
