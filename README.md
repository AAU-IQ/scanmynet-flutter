# scanmynet_sdk

Flutter plugin wrapping the ScanMyNet native Android SDK. Performs Wi-Fi network
scans (speed test, DNS, traceroute, device discovery) and submits results as a
report to the ScanMyNet backend.

## Prerequisites

| Tool | Version |
|------|---------|
| Flutter / Dart | ≥ 3.3.0 / ^3.12.0 |
| Android SDK | compileSdk 36, minSdk 24 |
| Java | 17 |
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

## See also

- [CONTRIBUTING.md](CONTRIBUTING.md) — developer setup and AAR update guide
