# Report payload → Flutter, and package publication

**Date:** 2026-07-20
**Status:** Approved design, pending implementation plan

## Problem

`POST /report/` gained three sibling keys — `report_id`, `customer_id`, and a
`report` object carrying the full 15-section scan payload (see
`report-response-mapping.md`). Earthlink needs that payload in Flutter to render
their own scan-result UI instead of embedding the hosted report.

Today the payload is unreachable from Dart on **both** platforms, and neither is
fixable from the `scanmynet_sdk` repo alone:

- **Android** — `ReportResponseDto` declares a single field, `data: String`. Gson
  silently discards the new keys before the plugin bridge ever sees the response.
- **iOS** — `struct ReportResponse: Codable { let data: String }`, and the
  delegate only surfaces `scanFinished(reportUrl: String)`. The body never
  crosses the framework boundary.

There is no read-path workaround. `GET /report/get_subscriber_report` returns a
smaller projection that the BE doc explicitly states is *not* a subset of
`report` (§7), and re-issuing `POST /report/` would create a duplicate report.

The native SDKs must therefore change first.

## Scope

In scope:

1. Widen the response models in `scanmynet-android` and `scanmynet-ios`.
2. Model all 15 report sections through Pigeon into Dart.
3. Prepare `scanmynet_sdk` for publication with integration documentation.

Out of scope:

- Any change to the `data` URL contract. It is byte-for-byte unchanged and
  remains the way to open the hosted report.
- Enrichment results (ElasticSearch indexing, customer records). Per the BE doc
  these run in a background task *after* the response is sent and are not in
  this payload.
- The `ScanDataPersisted` / `ScanReport` event, which carries the *request*
  payload (`ReportParamDto`) and is unrelated to this work.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Transport | Full Pigeon typing end-to-end | Chosen by project owner over JSON pass-through; gives compile-time typing in Kotlin, Swift and Dart |
| Section coverage | All 15 sections | Earthlink requires full parity with the web report UI |
| Native rebuild | Both SDKs | Source available for both; no vendor dependency |
| Publish target | Public pub.dev | Gated — see "Publication gate" below |

### Why full Pigeon typing carries recurring cost

Recorded so the trade-off is not re-discovered later. Pigeon generates strict
codecs into three languages. Because the AAR and xcframework ship *inside* the
plugin package, every backend field addition requires: edit the Pigeon schema →
regenerate → rebuild the Android AAR → rebuild and re-sign the iOS xcframework →
republish the plugin. The BE doc states the payload *"evolves with the FE
contract"* and warns against treating it as a stable versioned schema, so this
is the steady state rather than a rare event.

The alternative considered was passing the report as a JSON string through
native (precedent exists at `pigeons/messages.dart:209`) and typing only in
Dart, which would reduce future backend changes to a Dart-only release. The
project owner chose full typing for compile-time safety across all three
languages. This spec implements that choice.

## §1 — Native response models

Both SDKs already decode the response body, so both changes are a widening
rather than new decoder work.

### Android (`scanmynet-android`, `tools` module → version 1.1)

`tools/src/main/java/com/creative/tools/rest/dto/ReportResponseDto.kt`:

```kotlin
data class ReportResponseDto(
    val data: String,                    // unchanged
    val report_id: String? = null,
    val customer_id: String? = null,
    val report: ReportDto? = null,
)
```

Plus nested `*Dto` classes for the 15 sections.

The DTO package already contains `LocalDeviceDto`, `WifiNetworkDto`,
`CongestionDto`, `TracerouteDto`, `DnsLookupDto`, `PortDto`,
`ServerConnectivityDto` and `DnsPingResultDto`. These model the *request* shape
and are **not** reusable — response DTOs are separate types throughout.

The request/response divergence is real, not cosmetic. `CongestionDto.index` is
`Int?`, while the response's `channel_congestion[].index` is documented as a
string. `LocalDeviceDto` lacks the response's `average_ping_time`,
`connection_quality_color`, `device_details` and `is_subscriber_router`.
`DnsPingResultDto` lacks `jitter`, `average_ping_time`, `layer_ranking` and
`connection_quality_color`. Reusing either type would silently produce wrong
data. The request DTOs are useful only as a naming reference.

The rebuilt AAR is published to `android/local-maven-repo/` in `scanmynet_sdk`.

### iOS (`scanmynet-ios`)

`ScanMyNet/Models/Report.swift`:

```swift
struct ReportResponse: Codable {
    let data: String                     // unchanged
    let reportId: String?
    let customerId: String?
    let report: ReportPayload?
}
```

The payload is then threaded through two hops that currently discard everything
but the URL:

- `ReportManagerDelegate.reportSentSuccessfully(url:)` in `ReportManager.swift`
- `ScanMyNetDelegate.scanFinished(reportUrl:)` in `ScanMyNet.swift`

`ScanMyNetDelegate` is a public protocol. Adding a parameter to `scanFinished`
is a source-breaking change for existing native integrators, so a sibling method
is added with a default no-op implementation in a protocol extension:

```swift
func scanFinished(reportUrl: String, report: ReportPayload?)
```

The rebuilt xcframework replaces `ios/ScanMyNet.xcframework` in `scanmynet_sdk`.

### Nullability is a correctness requirement, not a style choice

Every added field on both platforms must be optional.

The BE doc states almost every field is nullable, sections are built from
whatever the SDK submitted, and a handful of keys are absent entirely rather
than null (`double_nat_detected`, `device_details`, `router_details`).

On iOS this is load-bearing. `ReportManager.sendReport()` routes a decode throw
to `sendReportFailed`, which surfaces as `scanFailed`. Swift `Codable` throws on
a missing non-optional key — so a single non-optional field the backend omits
would turn **every successful scan into a reported failure**. Gson is lenient
and would fail silently instead, which is quieter but equally wrong.

## §2 — Pigeon schema

Approximately 33 classes mirroring the 15 sections, added to
`pigeons/messages.dart`.

`ScanResult` gains three fields. The payload arrives in the same HTTP response
as `data`, so it belongs on the existing terminal event rather than a new one:

```dart
class ScanResult {
  String reportUrl;              // unchanged
  ScanResultStatus? status;      // unchanged
  int? totalDurationMs;          // unchanged
  String? reportId;              // new
  String? customerId;            // new
  ReportData? report;            // new
}
```

### Naming

The existing `ScanReport` (`pigeons/messages.dart:209`) carries the *request*
payload — the `ReportParamDto` JSON that was submitted. The new type is the
*response*. To avoid two unrelated types both named "report", the new type is
`ReportData` and `ScanReport` is left untouched; renaming it would be a breaking
Dart change for no benefit.

### Fields deliberately left untyped

Pigeon 26.3.4 supports `Map` and `Object`
(`lib/src/generator_tools.dart:473`), which covers the payload's irregular
shapes. Four are typed loosely on purpose:

| Payload shape | Pigeon type | Reason |
|---|---|---|
| `alert_type`, `action_type` | `String` | Pigeon enums throw on unrecognised values; BE adds members without a version bump. Wrapped as open enums in Dart. |
| `customer_internet_speed.connection_quality` | `Map<String, String>` | Single-entry map keyed by quality label (`{"good":"green"}`), not a struct. |
| `device_details.recognition` | `Map<String, Object?>` | Third-party Fing payload, explicitly open-ended. |
| `customer_details.last_known_public_ip_details` | `Map<String, String>` | Capitalised keys (`Country`, `Region`, `ISP`); individual keys may be absent. |

Note that `connection_quality_color` elsewhere in the payload (devices, DNS
results) genuinely *is* a `{quality, color}` struct and is typed as one. The two
must not share a type.

### Sections that are always present

The BE doc guarantees all 15 top-level keys are always present, with empty
sections as `{}` or `[]` rather than null. Sections are still modelled as
nullable in Pigeon, because `report` itself is nullable and an absent parent
makes every child absent.

`basic_connectivity.alerts` is documented as always empty — real alerts are
promoted to top-level `report.alerts`.

The two layers deliberately differ here. The Android DTO **does** model it, so
the response maps 1:1 onto the wire shape and nothing is silently dropped at the
decode boundary. The Pigeon schema **does not**, so Earthlink is never handed an
always-empty array to reason about. The asymmetry is intentional: the native
layer mirrors the payload, the public API exposes only what is useful.

## §3 — Native bridges

Mechanical DTO → Pigeon mapping in both plugin bridges:

- `android/src/main/kotlin/com/creativeadvtech/scanmynet_sdk/ScanHostApiImpl.kt`
- `ios/scanmynet_sdk/Sources/scanmynet_sdk/ScanHostApiImpl.swift`

iOS additionally implements the new delegate method. Both bridges own the
irregular-shape handling (capitalised keys, the single-entry quality map) so
those never reach the Pigeon schema.

The existing `buildReportUrl` logic on both sides is untouched.

## §4 — Dart surface

`ScanCompleted` carries the report via `ScanResult`. No new event type.

Open-enum wrappers over the `String` alert and action types, each with an
`unknown` fallback preserving the raw value. Consumers branch on `*_type` and
never on `*_value` — per the BE doc, values are display-ready English strings,
some templated at runtime (`"Connect to channel 11"`), and are not stable
identifiers.

Known members at time of writing:

- `alert_type`: `firewall`, `missing_upnp`, `double_nat`,
  `incomplete_speed_test`, `incomplete_scan`, `missing_location`, `old_router`,
  `network_utilization_alert`, `multicast_disabled`, `client_isolation_enabled`,
  `high_network_utilization`, `duplicate_ssid`, `range_extender`,
  `mesh_network`, `network_speed_loss`
- `action_type`: `incomplete_speedtest`, `high_router_usage_scan`,
  `download_speed`, `closer_to_the_router`, `connected_to_2ghz_network`,
  `recommended_channel`

### Version skew

Pigeon codecs are positional — the generated `_toList()`
(`lib/src/messages.g.dart:267`) encodes fields by index, not by name. A Dart
layer running against a mismatched native binary does not throw; it silently
misreads fields shifted by position, which would surface as corrupted scan data
rather than an error.

Because the AAR and xcframework ship inside the plugin package, this can only
occur during a partial upgrade or a stale native build. An explicit version
constant is exchanged during `configure()` and mismatches raise a
`FlutterError` so the failure is loud rather than silent.

New Pigeon fields are appended to the end of existing classes, never inserted.

## §5 — Publication

### Package metadata

`pubspec.yaml` currently fails a `pub publish` dry run:

- `description: "A new Flutter plugin project."` — placeholder
- `version: 0.0.1`
- `homepage:` — empty

Required: real description, `version: 1.0.0`, `homepage`/`repository`, and a
written `CHANGELOG.md` (currently a stub).

The package includes ~20 MB of tracked native binaries (74 files). This is
within pub.dev's 100 MB limit.

### Publication gate

Two blockers must be cleared by the project owner **before** `pub publish` runs.
Publication is irreversible: a version can be retracted within 7 days but
remains downloadable, and the package name is permanently claimed.

**1. Credential exposure.** `example/lib/app.dart:21` contains a working API
key (`<COMMITTED-KEY-REDACTED-ROTATE-ON-BACKEND>`; the adjacent comment confirms it is
valid). `pub publish` includes `example/` by design.

- *This spec's work:* remove the literal, read it from `--dart-define`, document
  the flag in the example README.
- *Owner's action:* rotate the key on the backend. It is already in git history,
  so scrubbing the working tree does not un-compromise it.

**2. License and redistribution rights.** `LICENSE` reads
`TODO: Add your license here.` Public publication grants the world a
redistribution right over the package — which includes three proprietary
third-party binaries: `ScanMyNet.xcframework`, `tools-1.0.aar`
(creativeadvtech), and `traceroute-1.0.0.aar` (synaptic-tools).

- *Owner's action:* confirm vendor agreements permit public redistribution, and
  add a real license. This is a legal determination, not a technical one.

Bundled data files were checked and are clean — `ConnectivityServers.plist` and
`Ports.json` contain only connectivity-test targets (BBC, Microsoft, Earthlink,
Kooora), no secrets.

### Integration documentation

Acceptance criteria require setup, usage and example docs:

- `README.md` — install, platform setup, permissions, quickstart, report payload
  guide, mapping hazards from the BE doc
- `CHANGELOG.md` — 1.0.0 entry
- dartdoc on all public API
- `example/` — already exists and covers setup and usage; extended to render
  report sections

## Sequencing and risk

The dependency chain is strictly ordered and nothing downstream is testable
until the step above it ships:

```
scanmynet-android ─┐
                   ├─► scanmynet_sdk (Pigeon → bridges → Dart) ─► publish
scanmynet-ios ─────┘
```

The two native changes are independent and can proceed in parallel. Both must
land — with rebuilt binaries copied into `scanmynet_sdk` — before the Pigeon
schema can be exercised end-to-end.

Principal risks:

1. **Field-mapping drift.** ~60 classes hand-mapped in four languages against a
   prose document. Mitigated by a golden-JSON fixture test: a recorded response
   decoded through each layer and asserted field-by-field.
2. **iOS decode regression.** A non-optional field turns every scan into a
   failure (§1). Mitigated by a decode test against a minimal response
   containing only `data`.
3. **Backend drift during implementation.** The payload tracks the FE contract.
   The golden fixture should be re-captured from a live scan immediately before
   publication.

## Testing

- **Android:** unit tests decoding a golden JSON fixture into `ReportResponseDto`
  and mapping to Pigeon; a minimal `{"data": "..."}` response must decode.
- **iOS:** equivalent `Codable` tests, explicitly including the minimal-response
  case.
- **Dart:** decode tests over the same golden fixture; open-enum fallback for an
  unknown `alert_type`/`action_type`; existing plugin tests must keep passing.
- **Integration:** the example app renders a full report end-to-end on a real
  device against a live scan.

The same golden fixture is used at all three layers so drift surfaces as a test
failure rather than a rendering bug.
