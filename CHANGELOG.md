## 1.1.9

All Android, and **required if your app uses Jetpack Compose** — on every
earlier release the SDK could crash a Compose host app that never called
ScanMyNet at all.

* **Fix (Android):** the SDK shipped `xmlpull:xmlpull:1.1.3.1`, a 2003 jar that
  redeclares `org.xmlpull.v1.XmlPullParser` — a class Android already provides.
  Shipping it moved the type into R8's *program* set, so R8 renamed it and
  rewrote Compose's call sites to the renamed type. At runtime the framework
  returns a parser implementing the real interface, the call has no valid
  target, and **any `painterResource()` anywhere in the host app** — any Compose
  vector icon — died with an NPE inside `loadVectorResource`. No ScanMyNet call
  was needed to trigger it; adding the dependency was enough. Debug builds hit
  the same defect differently, as `XmlPullParserException:
  defineEntityReplacementText() not supported`.

* **Fix (Android):** the SDK also exposed `retrofit2:converter-jaxb` at `api`
  scope, which references `javax.xml.stream.*` — absent on Android. Consumers
  enabling R8 got a hard build failure until they added `-dontwarn` rules for a
  library they never asked for. Those rules are no longer needed.

* **Fix (Android):** five further dependencies with no code references are gone
  — Volley, WorkManager, AppCompat, Material and the Firebase Crashlytics
  *build* tool, which was being shipped as a runtime dependency. Smaller dex,
  and five fewer jars whose contents nobody had inspected.

Nothing in the SDK's behaviour or API changes. If you applied the
`exclude group: 'xmlpull'` workaround in your app's `build.gradle`, you can
remove it after upgrading.

## 1.1.8

All iOS, and **strongly recommended for anyone on 1.1.7** — on that release an
iOS scan could finish and then be thrown away.

* **Fix (iOS):** a completed scan was rejected by the backend with
  `local_devices - manufacturer: ensure this value has at least 1 characters`,
  and the whole report was discarded. Submission is all-or-nothing, so one blank
  field on one device cost every measurement in the scan — speed, ping,
  traceroute and all. Introduced in 1.1.7, where the manufacturer stopped being
  a fixed string and started being read for real.

* **Fix (iOS):** device manufacturers now resolve, for the first time. The SDK
  looks each one up from the MAC's OUI prefix in a 22,857-entry table that ships
  inside `ScanMyNet.framework` — but it was searching the *host app's* bundle
  for that table, where it has never been. The lookup therefore missed in every
  app that has ever embedded the SDK, and every device came back unnamed. That
  empty value is what 1.1.7 then submitted.

* **Fix (iOS):** `make` and `model_number` are now sent. The Android SDK reports
  the router's manufacturer as both `make` and `manufacturer`; iOS filled only
  the second. `model_number` was parsed out of the UPnP description and then
  dropped.

* **Fix (iOS):** an unresolvable DNS host submitted a blank `dns_ip` instead of
  falling back to its hostname, and an unreadable Wi-Fi address submitted a
  blank `ssid_ip` — the same blank-versus-absent confusion as above, at three
  more report boundaries.

## 1.1.7

All iOS. Nothing on the Dart side changed; every fix here is in the bundled
native SDK.

* **Fix (iOS):** the router was whichever device answered an SSDP search first.
  On a network with a TV or a set-top box, three consecutive scans could name
  three different "routers", and a gateway that answers no SSDP — most of them —
  was never among them. Since the connection-quality and server-connectivity
  steps both measure against that address, the whole link-quality measurement
  could be aimed at someone's television. The router is now the default route,
  which is what the Android SDK has always used.

* **Fix (iOS):** `routerMacAddress` is now reported. The backend only returns
  the router section of a report once it knows the router's MAC, and resolves
  the connected Wi-Fi network from it — so on iOS the router details and the
  Wi-Fi details were empty no matter what the scan found.

* **Fix (iOS):** a UPnP description missing any one field was discarded whole,
  so a router that omits, say, `modelDescription` produced no make, model or
  friendly name at all rather than the fields it did send. A gateway that
  answers no SSDP now falls back to the best other device that did, matching
  how the Android SDK picks.

* **Fix (iOS):** traceroute submitted nothing on every scan. Six traceroutes
  shared one serial queue against a 20-second budget, so the first consumed it
  and the rest never started. They now run concurrently, and whatever has been
  measured is reported when the budget expires rather than discarded.

* **Fix (iOS):** the speed test reported an upload of 0. It was posting to a URL
  that discards the request body after the first TCP window, so almost none of
  the payload left the device. See the README on comparing upload figures with
  Android — they will not match until Android moves to the same endpoint.

* **Fix (iOS):** ping, jitter and packet-loss readings. A reply was timed
  against whichever packet was sent most recently rather than the one it
  answered, so on a link where replies take longer than the send interval every
  latency was wrong. Lost packets are now recorded in the position they were
  lost, which is what the backend derives jitter from.

* **Fix (iOS):** every device in `localConnectedDevices` reported its
  manufacturer as "Unknown". The lookup had been resolving the real
  manufacturer from the MAC all along; the result was being dropped.

* **Fix (iOS):** the scan's `start` timestamp used the ISO week-numbering year
  and the device's local time zone, where Android sends the calendar year in
  UTC. Around New Year a scan was filed under the wrong year, and everywhere
  else it disagreed with Android by the device's UTC offset.

* **Added (iOS):** `networkUsageDown` / `networkUsageUp` — the traffic the scan
  itself moved. Previously Android-only.

* **Docs:** the README now lists what iOS cannot measure and why, so a thin
  Wi-Fi or congestion section can be told apart from a failed scan.

## 1.1.6

* **Fix (iOS):** packet loss and ping readings were partly invented. The
  "dropped" counter started at its maximum and counted down on each reply, and
  "sent" reported the number of packets intended rather than the number sent -
  so "everything was dropped" was the starting state, not a measurement. A host
  that answered 8 of 10 pings before the run ended early was reported as 73%
  packet loss instead of 20%. Ping targets that failed the reachability check
  were reported too, each carrying a full set of dropped packets without one
  having left the device. Both the per-host and per-device readings now report
  what actually happened.

* **Fix (iOS):** a second scan in the same session could sit on Connection
  Quality for 90 seconds and then submit the *previous* scan's ping results as
  its own. Per-scan state was only cleared on cancel, never on a scan that ran
  to completion.

* **Fix (iOS):** on networks that block ICMP outright, Connection Quality waited
  out its full 90-second timeout with nothing left to do. It now finishes as
  soon as every host is accounted for.

* **Changed (iOS):** the speed test now measures against the same server, with
  the same file sizes and the same sampling, as the Android SDK. It previously
  used NDT7, which measured against whichever M-Lab server it was handed - Tel
  Aviv, for scans run from Iraq - while Android measured against Scaleway in
  Paris. The same device on the same network got two numbers with no reason to
  agree. The `NDT7` pod dependency is gone; run `pod install` after upgrading.

* **Added (iOS):** `ScanResult.reportId` and `ScanResult.customerId` are now
  populated. They had been Android-only, so a Flutter app reading either got an
  answer on one platform and null on the other.

## 1.1.5

* **Fix (iOS):** a scan could stall on its first step indefinitely, showing
  `0% Working on Router UPNP` until the app was restarted. Router discovery
  sends an SSDP M-SEARCH to a multicast address, and every way that could fail
  was a dead end that never told the scan to move on - including the 10s
  watchdog, which was disarmed by the very errors it existed to catch.
  Discovery now always ends, within its timeout at worst.

* **Fix (iOS):** cancelling a scan left the UI on "Scanning...". The SDK emitted
  a progress event *after* the cancel; that order is fixed, and the example
  ignores progress arriving when no scan is running.

* **iOS setup:** apps now need `com.apple.developer.networking.multicast` and
  `com.apple.developer.networking.wifi-info` entitlements, plus
  `NSBonjourServices` and an `NSAllowsLocalNetworking` ATS exception - a
  router's UPnP description is served over plain HTTP, which ATS blocks by
  default. Without these, router and LAN discovery silently find nothing. The
  README lists every key and what each one breaks. Multicast is not self-serve -
  Apple grants it per App ID on request.

## 1.1.4

* **Fix (iOS):** a scan whose report the server accepted could still arrive as
  `ScanFailed` with `kind: submission`, carrying the successful response body as
  its message. Reports listing blocked ports hit this, so it showed up on any
  network with a firewall.

  The backend serializes ports as numeric strings (`"20"`). Android's Gson
  coerces them; iOS's `JSONDecoder` threw, and the native SDK routed that decode
  error to its failure path. Fixed in the bundled `ScanMyNet.xcframework` — the
  report payload now also decodes fail-safe, so future drift yields
  `ScanResult.report == null` instead of failing a scan that succeeded.

  Binary only: no Dart or Swift API change. Android was never affected.

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
