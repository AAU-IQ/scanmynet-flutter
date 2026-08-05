## 1.1.0

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
  (`tools:1.2`) instead of a table duplicated in this plugin, so a URL changes
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
