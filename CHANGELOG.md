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
