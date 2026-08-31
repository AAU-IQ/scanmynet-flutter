## 1.1.3

* **Fix (Android, crash):** cancelling a scan while the download speed test was
  running could kill the host app. Reproduces by starting a scan and turning
  Wi-Fi off from the notification shade during the download speed test.

  A cancelled scan disposes the native SDK's Rx chain, but the speed test keeps
  running — and cancelling closes its sockets, which makes it fail. That late
  error reached the thread's uncaught exception handler and took the process
  down. Fixed in the native SDK (`tools:1.5`); no API or behaviour change here.

  `ScanmynetSdk.cancel()` is the call that triggered it, so any app cancelling a
  scan — including on backgrounding — is affected.

## 1.1.2

Metadata only — no code, API, or behaviour change.

* `repository`/`homepage` now point at https://github.com/AAU-IQ/scanmynet-flutter.
  They previously pointed at a private URL that returned 404, so the links from
  pub.dev went nowhere. `issue_tracker` added.

## 1.1.1

* **Fix (Android, ship-blocking):** Android Studio and Play Console flagged apps
  using this plugin — two bundled native libraries had `LOAD` segments aligned
  to 4 KB, which Android 15+ cannot map on a 16 KB-page device.

  Both came from the native SDK's `com.synaptic-tools:traceroute` dependency:
  `libtraceroute.so` and the `libc++_shared.so` beside it, in `arm64-v8a` and
  `x86_64`. (32-bit ABIs are exempt.) Upstream has shipped no rebuild since
  2021, and the ELF headers could not be patched in place, so the library was
  rebuilt from the same sources with NDK 28.2 and
  `-Wl,-z,max-page-size=16384`. It arrives here as `tools:1.4`, which depends
  on `traceroute:1.0.1`.

  Nothing else in the plugin was affected — the other libraries named in the
  warning belong to Flutter itself (already 64 KB-aligned) or to other packages
  in the app. No API or behaviour change: all 56 `Java_*` JNI entry points are
  byte-identical to the previous build in every ABI.

  Verified in a consuming app: the final APK has zero unaligned 64-bit
  libraries, and every `.so` is `STORED` on a 16 KB boundary inside the zip as
  `extractNativeLibs=false` requires.

* Dropped the four superseded `tools` AARs and the old `traceroute` AAR from the
  bundled Maven repository — the plugin resolves exactly one version of each, so
  the rest were dead weight downloaded by every consumer. The bundled Maven
  repository drops from 5.3 MB to 2.4 MB on disk, and stops shipping the
  obfuscated `tools-1.1.aar` named in the 1.1.0 duplicate-class fix.

## 1.1.0

* **Fix (Android, build-blocking):** an app combining this plugin with another
  obfuscated AAR failed to build with
  `Duplicate class a.a … in modules <other>.aar and tools-1.1.aar`.

  The bundled `tools-1.1.aar` was published obfuscated, which renamed 61 of its
  classes into single-letter root packages (`a.a`, `b.a`, `c.a` …) — names any
  other obfuscated AAR also claims. The native SDK now publishes unobfuscated
  (`tools:1.3`); shrinking is the consuming app's job, and the keep rules it
  needs still ship via `consumerProguardFiles`. No API or behaviour change.

  Reported against `babylai_flutter`, and verified there: the duplicate-class
  check fails on `tools:1.1` and passes on `tools:1.3` with both AARs on the
  same runtime classpath.

* **Feature:** `ScanEnvironment.custom` points a scan at a self-hosted ScanMyNet
  deployment instead of ours. Pass the server root as `ScanConfig.customBaseUrl`
  — not an endpoint, since each SDK still appends its own `/api/v1/…` paths, so
  the deployment must expose the same endpoint names ours does. A trailing slash
  is optional.

  ```dart
  await sdk.configure(ScanConfig(
    apiKey: 'your-key',
    environment: ScanEnvironment.custom,
    customBaseUrl: 'https://smn.example.com/',
  ));
  ```

* `ScanConfig.customFrontendUrl` sets the report-viewer root when a different
  host serves it. Omitted, the viewer is served from `customBaseUrl` — never
  from our production host, which would put an operator's `verification_token`
  on our domain.

* `configure` throws `ArgumentError` when `custom` is selected without a base
  URL, and is now `async`, so that validation arrives as a rejected Future
  rather than a synchronous throw that would slip past `.catchError`.

* Android backend URLs now come from the native SDK's `Environment`
  (`tools:1.3`) instead of a table duplicated in this plugin, so a URL changes
  in one place. No Dart API change.

* Pigeon `schemaVersion` 2 → 3 (`ScanConfig` gained two fields). The native
  binaries must be rebuilt in step; a skewed pair throws on `configure`.

* Requires the rebuilt `ScanMyNet.xcframework` on iOS, which adds the native
  `Environment.custom(baseUrl:frontendUrl:)` case. Bundled.

## 1.0.2

* **Fix (Android, build-blocking):** consuming apps failed to resolve one of the
  native SDK's bundled dependencies. The bundled AAR repository was only
  registered on the plugin's own project, but the app resolves that dependency
  on its own runtime classpath. The repository (and JitPack, for a transitive
  dependency) is now registered with the whole consuming build, so no Gradle
  changes are needed in the host app.
* Docs: corrected the Android setup section — it previously claimed "no extra
  setup required". Consuming apps must declare location permissions (and grant
  `ACCESS_FINE_LOCATION` at runtime) and permit cleartext HTTP via a
  `networkSecurityConfig`, otherwise the Wi-Fi section is anonymised and the
  router's make/model comes back "Unknown".

## 1.0.1

* Docs: expanded the README with a full `Usage` / API section and a "Building
  your own UI from the report" guide mapping all 15 `ReportData` sections, plus
  a pointer to the example's `ReportSummaryCard`. No code changes.

## 1.0.0

* First stable release.
* `ScanResult` now carries the full report payload (`report`), plus `reportId`
  and `customerId`, alongside the existing hosted-report `reportUrl`.
* Added `ReportData` covering all 15 report sections.
* Added `AlertType` and `ActionType` open enums with an `unknown` fallback for
  values added by the backend after this release.
* Added a Pigeon schema version handshake between Dart and the native SDKs.

## 0.0.1

* Initial development release.
