# Report Payload — iOS Native (Plan 2 of 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Widen the iOS SDK's `POST /report/` response model so the full 15-section `report` object, `report_id` and `customer_id` decode and reach the Flutter plugin through `ScanMyNetDelegate`.

**Architecture:** `ReportResponse` currently declares one field (`data: String`) and `ReportManager` discards everything but the URL. We add public, fully-optional `Codable` response models covering all 15 sections, then thread the payload through the two delegate hops that currently drop it. The existing `scanFinished(reportUrl:)` contract is preserved; a defaulted sibling method carries the payload.

**Tech Stack:** Swift, `Codable` / `JSONDecoder`, XCTest, CocoaPods, `xcodebuild -create-xcframework`.

**Repo:** `C:\Users\abdal\BitBucket\scanmynet-ios`

**Spec:** `scanmynet_sdk/docs/superpowers/specs/2026-07-20-report-payload-and-publish-design.md`

> ## ⚠️ This plan requires macOS
>
> The project is an `.xcworkspace` driven by `xcodebuild`. It cannot be built,
> tested, or packaged on the Windows machine where the spec was authored. Execute
> on a Mac with Xcode, or through the existing Bitrise CI (`bitrise.yml`). Every
> command below assumes a macOS shell.

## Global Constraints

- **Every new field is optional.** This is a correctness requirement, not style. `ReportManager.sendReport()` routes a decode throw to `sendReportFailed` → `scanFailed`. Swift `Codable` throws on a missing non-optional key, so one non-optional field the backend omits would turn **every successful scan into a reported failure**.
- **`data: String` stays exactly as-is** — non-optional, unchanged. It is the shipped contract.
- **Explicit `CodingKeys` on every type.** Never add `.convertFromSnakeCase` to the decoder: `customer_details.last_known_public_ip_details` has capitalised keys (`Country`, `Region`, `ISP`) that do not round-trip through it. This matches the existing `Report` type's convention.
- **All response types are `public`.** They cross the framework module boundary via the public `ScanMyNetDelegate`. `ReportResponse` itself stays internal — only the nested payload is exposed.
- **`alertType` / `actionType` are `String?`.** Never Swift enums — the backend adds members without an API version bump, and a `RawRepresentable` enum would throw on an unknown value.
- **Response models live in** `ScanMyNet/Models/Response/`.
- **Do not commit.** The project owner has held all commits across all three repos. Each task ends with a staging checkpoint and the message to use once approval lands.
- Podspec version stays `1.0.2` until Task 8, which bumps it to `1.1.0`.

---

### Task 1: Test target, fixtures, and top-level response widening

The repo has **no test target** — `find -iname "*Tests*"` returns nothing and the pbxproj declares none. This task creates one, then proves the two contracts that must never break.

**Files:**
- Create (via Xcode): `ScanMyNetTests/` target
- Create: `ScanMyNetTests/Fixtures/report_response_full.json`
- Create: `ScanMyNetTests/Fixtures/report_response_minimal.json`
- Modify: `ScanMyNet/Models/Report.swift:4-6`
- Create: `ScanMyNet/Models/Response/SMNReportPayload.swift`
- Create: `ScanMyNetTests/ReportResponseTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `ReportResponse(data:reportId:customerId:report:)`, `public struct SMNReportPayload` (placeholder, populated in Tasks 2-6), and test helper `loadFixture(_ name: String) -> Data`.

- [ ] **Step 1: Create the unit test target in Xcode**

pbxproj surgery by hand is error-prone; use the GUI once.

1. Open `ScanMyNet.xcworkspace`.
2. **File → New → Target… → iOS → Unit Testing Bundle**.
3. Product Name: `ScanMyNetTests`. Target to be Tested: `ScanMyNet`.
4. In the new target's **Build Phases → Copy Bundle Resources**, confirm `ScanMyNetTests/Fixtures/` is included once created.
5. Close Xcode so the pbxproj is flushed to disk.

Verify the scheme can see it:

```bash
cd ~/path/to/scanmynet-ios
xcodebuild -workspace ScanMyNet.xcworkspace -list | grep -A5 Targets
```

Expected: `ScanMyNetTests` appears under Targets.

- [ ] **Step 2: Add the fixtures**

Create `ScanMyNetTests/Fixtures/report_response_minimal.json` — the regression guard:

```json
{
  "info": { "message": "success", "details": {} },
  "data": "https://scanmynet.earthlink.iq/#/view-report/?verification_token=abc123"
}
```

Create `ScanMyNetTests/Fixtures/report_response_full.json` with **identical content** to the Android plan's fixture (`scanmynet-android/tools/src/test/resources/report_response_full.json`). Copy it verbatim — both platforms must assert against byte-identical input, so a divergence between the two SDKs surfaces as a test failure.

```bash
cp "../scanmynet-android/tools/src/test/resources/report_response_full.json" \
   "ScanMyNetTests/Fixtures/report_response_full.json"
```

- [ ] **Step 3: Write the failing test**

`ScanMyNetTests/ReportResponseTests.swift`:

```swift
import XCTest
@testable import ScanMyNet

final class ReportResponseTests: XCTestCase {

    func testMinimalResponseDecodesAndDataIsUnchanged() throws {
        let response = try JSONDecoder().decode(
            ReportResponse.self,
            from: loadFixture("report_response_minimal")
        )

        XCTAssertEqual(
            response.data,
            "https://scanmynet.earthlink.iq/#/view-report/?verification_token=abc123"
        )
        XCTAssertNil(response.reportId)
        XCTAssertNil(response.customerId)
        XCTAssertNil(response.report)
    }

    func testFullResponseDecodesTopLevelIdentifiers() throws {
        let response = try JSONDecoder().decode(
            ReportResponse.self,
            from: loadFixture("report_response_full")
        )

        XCTAssertEqual(response.reportId, "6f1b2c40-0000-0000-0000-0000a91e")
        XCTAssertEqual(response.customerId, "acme-key")
    }
}

func loadFixture(_ name: String) -> Data {
    let url = Bundle(for: ReportResponseTests.self)
        .url(forResource: name, withExtension: "json")!
    return try! Data(contentsOf: url)
}
```

- [ ] **Step 4: Run the test to verify it fails**

```bash
xcodebuild test \
  -workspace ScanMyNet.xcworkspace \
  -scheme ScanMyNet \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

Expected: FAIL — `value of type 'ReportResponse' has no member 'reportId'`.

- [ ] **Step 5: Widen `ReportResponse`**

In `ScanMyNet/Models/Report.swift`, replace lines 4-6:

```swift
/// Response of a successful report submission.
///
/// `data` is the shipped contract and is unchanged. The remaining fields were
/// added alongside it and are absent on older backends, so all are optional —
/// a missing non-optional key would throw, and `ReportManager` routes a decode
/// throw to `sendReportFailed`, turning a successful scan into a failure.
struct ReportResponse: Codable {
    let data: String
    let reportId: String?
    let customerId: String?
    let report: SMNReportPayload?

    enum CodingKeys: String, CodingKey {
        case data
        case reportId = "report_id"
        case customerId = "customer_id"
        case report
    }
}
```

- [ ] **Step 6: Create the placeholder `SMNReportPayload`**

Create `ScanMyNet/Models/Response/SMNReportPayload.swift`:

```swift
import Foundation

/// The full report payload returned alongside the hosted report URL.
///
/// All 15 section keys are always present in the JSON, but every one is
/// modelled optional: the parent `report` object itself is optional, and an
/// absent parent makes every child absent.
///
/// This mirrors the frontend contract and evolves with it — it is NOT a stable
/// versioned schema.
///
/// Sections are introduced incrementally (plan Tasks 2-6). Untyped sections are
/// omitted entirely rather than stubbed, so a partially-implemented build never
/// silently decodes a section to nil.
public struct SMNReportPayload: Codable {
    public let incompleteAnalysis: Bool?

    enum CodingKeys: String, CodingKey {
        case incompleteAnalysis = "incomplete_analysis"
    }
}
```

- [ ] **Step 7: Run the test to verify it passes**

```bash
xcodebuild test -workspace ScanMyNet.xcworkspace -scheme ScanMyNet \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

Expected: PASS, 2 tests.

- [ ] **Step 8: Staging checkpoint (do not commit)**

```bash
git add ScanMyNet/Models/Report.swift ScanMyNet/Models/Response/ ScanMyNetTests/ ScanMyNet.xcodeproj/project.pbxproj
```

Message: `feat(response): add test target and widen ReportResponse`

---

### Task 2: Scalar sections — customer details, SDK details, usage, speed

**Files:**
- Create: `ScanMyNet/Models/Response/ScalarSections.swift`
- Modify: `ScanMyNet/Models/Response/SMNReportPayload.swift`
- Create: `ScanMyNetTests/ScalarSectionsTests.swift`

**Interfaces:**
- Consumes: `SMNReportPayload`, `loadFixture`.
- Produces: `SMNCustomerDetails`, `SMNSDKDetails`, `SMNRouterUsage`, `SMNInternetSpeed`. `SMNInternetSpeed.connectionQuality` is `[String: String]?` — a single-entry map keyed by the quality label.

- [ ] **Step 1: Write the failing test**

`ScanMyNetTests/ScalarSectionsTests.swift`:

```swift
import XCTest
@testable import ScanMyNet

final class ScalarSectionsTests: XCTestCase {

    private func report() throws -> SMNReportPayload {
        try JSONDecoder()
            .decode(ReportResponse.self, from: loadFixture("report_response_full"))
            .report!
    }

    func testCustomerDetailsKeepsCapitalisedGeoKeys() throws {
        let details = try report().customerDetails!
        XCTAssertEqual(details.key, "acme-key")
        XCTAssertEqual(details.lastKnownPublicIP, "203.0.113.10")
        XCTAssertEqual(details.lastKnownPublicIPDetails?["Country"], "US")
        XCTAssertEqual(details.lastKnownPublicIPDetails?["Region"], "Austin")
        XCTAssertEqual(details.lastKnownPublicIPDetails?["ISP"], "Example ISP")
    }

    func testSDKDetailsDecodes() throws {
        let sdk = try report().sdkDetails!
        XCTAssertEqual(sdk.duration, 42)
        XCTAssertEqual(sdk.platform, "android")
        XCTAssertEqual(sdk.gpsLatitude!, 30.2672, accuracy: 0.0001)
    }

    func testRouterUsageDecodes() throws {
        let usage = try report().routerUsageDuringScan!
        XCTAssertEqual(usage.networkUsageDown!, 1.4, accuracy: 0.001)
        XCTAssertEqual(usage.networkUsageUp!, 0.3, accuracy: 0.001)
    }

    func testConnectionQualityIsSingleEntryMapKeyedByLabel() throws {
        let speed = try report().customerInternetSpeed!
        XCTAssertEqual(speed.networkSpeedDown!, 87.4, accuracy: 0.001)
        XCTAssertEqual(speed.networkSpeedDownSegments!, [85.1, 89.7])

        let quality = speed.connectionQuality!
        XCTAssertEqual(quality.count, 1)
        XCTAssertEqual(quality.first!.key, "good")
        XCTAssertEqual(quality.first!.value, "green")
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
xcodebuild test -workspace ScanMyNet.xcworkspace -scheme ScanMyNet \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:ScanMyNetTests/ScalarSectionsTests
```

Expected: FAIL — no member `customerDetails`.

- [ ] **Step 3: Create `ScalarSections.swift`**

```swift
import Foundation

/// Subscriber key, public IP and resolved geo.
///
/// `lastKnownPublicIPDetails` keys are CAPITALISED (`Country`, `Region`, `ISP`)
/// and do not follow the snake_case of the rest of the payload. It is held as a
/// raw dictionary so no key transformation is applied — this is also why the
/// decoder must never use `.convertFromSnakeCase`. The dictionary is `{}` when
/// geo did not resolve, and individual keys may be missing rather than null.
public struct SMNCustomerDetails: Codable {
    public let key: String?
    public let lastKnownPublicIP: String?
    public let lastKnownPublicIPDetails: [String: String]?

    enum CodingKeys: String, CodingKey {
        case key
        case lastKnownPublicIP = "last_known_public_ip"
        case lastKnownPublicIPDetails = "last_known_public_ip_details"
    }
}

/// Scan run metadata. `duration` is in seconds.
///
/// When either GPS field is nil the backend emits a `missing_location` alert.
public struct SMNSDKDetails: Codable {
    public let start: String?
    public let duration: Int?
    public let platform: String?
    public let app: String?
    public let routeThisSDK: String?
    public let userPublicUpAddress: String?
    public let gpsLatitude: Double?
    public let gpsLongitude: Double?

    enum CodingKeys: String, CodingKey {
        case start, duration, platform, app
        case routeThisSDK = "route_this_sdk"
        case userPublicUpAddress = "user_public_up_address"
        case gpsLatitude = "gps_latitude"
        case gpsLongitude = "gps_longitude"
    }
}

/// Router usage counters observed during the scan, in Mbps.
public struct SMNRouterUsage: Codable {
    public let networkUsageDown: Double?
    public let networkUsageUp: Double?

    enum CodingKeys: String, CodingKey {
        case networkUsageDown = "network_usage_down"
        case networkUsageUp = "network_usage_up"
    }
}

/// Speed test results.
///
/// `connectionQuality` is a SINGLE-ENTRY MAP keyed by the quality label —
/// `["poor": "red"]`, `["moderate": "yellow"]` or `["good": "green"]` — and is
/// `[:]` when `networkSpeedDown` is nil. It is NOT a `{quality, color}` struct;
/// that shape is `SMNQualityColor`, used elsewhere in the payload.
public struct SMNInternetSpeed: Codable {
    public let networkSpeedDown: Double?
    public let networkSpeedUp: Double?
    public let currentNegotiatedLinkSpeed: Double?
    public let maximumLinkSupportedByPhone: String?
    public let networkSpeedUpSegments: [Double]?
    public let networkSpeedDownSegments: [Double]?
    public let connectionQuality: [String: String]?

    enum CodingKeys: String, CodingKey {
        case networkSpeedDown = "network_speed_down"
        case networkSpeedUp = "network_speed_up"
        case currentNegotiatedLinkSpeed = "current_negotiated_link_speed"
        case maximumLinkSupportedByPhone = "maximum_link_supported_by_phone"
        case networkSpeedUpSegments = "network_speed_up_segments"
        case networkSpeedDownSegments = "network_speed_down_segments"
        case connectionQuality = "connection_quality"
    }

    /// Normalises the single-entry map into a usable pair.
    public var quality: (label: String, color: String)? {
        guard let first = connectionQuality?.first else { return nil }
        return (first.key, first.value)
    }
}
```

- [ ] **Step 4: Wire into `SMNReportPayload`**

```swift
public struct SMNReportPayload: Codable {
    public let customerDetails: SMNCustomerDetails?
    public let sdkDetails: SMNSDKDetails?
    public let routerUsageDuringScan: SMNRouterUsage?
    public let customerInternetSpeed: SMNInternetSpeed?
    public let incompleteAnalysis: Bool?

    enum CodingKeys: String, CodingKey {
        case customerDetails = "customer_details"
        case sdkDetails = "sdk_details"
        case routerUsageDuringScan = "router_usage_during_scan"
        case customerInternetSpeed = "customer_internet_speed"
        case incompleteAnalysis = "incomplete_analysis"
    }
}
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
xcodebuild test -workspace ScanMyNet.xcworkspace -scheme ScanMyNet \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:ScanMyNetTests/ScalarSectionsTests
```

Expected: PASS, 4 tests.

- [ ] **Step 6: Staging checkpoint (do not commit)**

```bash
git add ScanMyNet/Models/Response/ ScanMyNetTests/
```

Message: `feat(response): add customer details, sdk details, usage and speed sections`

---

### Task 3: Basic connectivity

**Files:**
- Create: `ScanMyNet/Models/Response/SMNBasicConnectivity.swift`
- Modify: `ScanMyNet/Models/Response/SMNReportPayload.swift`
- Create: `ScanMyNetTests/BasicConnectivityTests.swift`

**Interfaces:**
- Consumes: `SMNReportPayload`, `loadFixture`.
- Produces: `SMNBasicConnectivity`, `SMNServerConnectivityResult`, `SMNPortCheckResult`, `SMNDNSLookupResult`, `SMNConnectivitySummary`, `SMNStatusColor`, `SMNToggleState`, `SMNReportAlert`. `SMNReportAlert` is reused by Task 6's top-level `alerts`.

> Type names avoid collisions with the existing request-side models in
> `ScanMyNet/Models/`: `ServerConnectivity`, `PortCheck` and `DNSLookup` already
> exist there. Response types take the `…Result` suffix.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import ScanMyNet

final class BasicConnectivityTests: XCTestCase {

    private func connectivity() throws -> SMNBasicConnectivity {
        try JSONDecoder()
            .decode(ReportResponse.self, from: loadFixture("report_response_full"))
            .report!.basicConnectivity!
    }

    func testDecodesListsAndDHCPFlag() throws {
        let c = try connectivity()
        XCTAssertEqual(c.ipAssignedViaDHCP, true)
        XCTAssertEqual(c.serverConnectivity?.first?.name, "google")
        XCTAssertEqual(c.serverConnectivity?.first?.serverStatus, true)
        XCTAssertEqual(c.portChecks?.first?.port, 443)
        XCTAssertEqual(c.portChecks?.first?.portType, "tcp")
        XCTAssertEqual(c.dnsLookup?.first?.reverseDNS, "dns.google")
    }

    func testSummaryDNSLookupIsStringListWhileSiblingsAreObjects() throws {
        let summary = try connectivity().summary!
        XCTAssertEqual(summary.serverConnectivity?.color, "green")
        XCTAssertEqual(summary.portChecks?.status, "good connectivity")
        XCTAssertEqual(summary.dnsLookup, ["google", "cloudflare"])
    }

    func testToggleValuesAreEnabledDisabledStringsNotBooleans() throws {
        let c = try connectivity()
        XCTAssertEqual(c.firewall?.value, "Disabled")
        XCTAssertEqual(c.clientIsolation?.value, "Disabled")
        XCTAssertEqual(c.multicast?.value, "Enabled")
    }

    func testBlockedListsDecodeWithCorrectElementTypes() throws {
        // `servers` is a list of names (Server.name: str) while `udp`/`tcp` are
        // port numbers (Port.port: int) — different element types, easy to
        // conflate when the fixture leaves them empty.
        let c = try connectivity()
        XCTAssertEqual(c.servers, ["blocked-example"])
        XCTAssertEqual(c.udp, [53])
        XCTAssertEqual(c.tcp, [8080])
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
xcodebuild test -workspace ScanMyNet.xcworkspace -scheme ScanMyNet \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:ScanMyNetTests/BasicConnectivityTests
```

Expected: FAIL — no member `basicConnectivity`.

- [ ] **Step 3: Create `SMNBasicConnectivity.swift`**

```swift
import Foundation

/// Firewall, port, DNS and multicast checks.
///
/// `servers`, `udp` and `tcp` list the *blocked* server names and port numbers.
///
/// `alerts` is ALWAYS an empty array — real alerts are promoted to the
/// top-level `report.alerts`. Modelled only so the field is accounted for; do
/// not read it.
public struct SMNBasicConnectivity: Codable {
    public let ipAssignedViaDHCP: Bool?
    public let serverConnectivity: [SMNServerConnectivityResult]?
    public let portChecks: [SMNPortCheckResult]?
    public let dnsLookup: [SMNDNSLookupResult]?
    public let summary: SMNConnectivitySummary?
    public let servers: [String]?
    public let udp: [Int]?
    public let tcp: [Int]?
    public let firewall: SMNToggleState?
    public let clientIsolation: SMNToggleState?
    public let multicast: SMNToggleState?
    public let alerts: [SMNReportAlert]?

    enum CodingKeys: String, CodingKey {
        case summary, servers, udp, tcp, firewall, multicast, alerts
        case ipAssignedViaDHCP = "ip_assigned_via_dhcp"
        case serverConnectivity = "server_connectivity"
        case portChecks = "port_checks"
        case dnsLookup = "dns_lookup"
        case clientIsolation = "client_isolation"
    }
}

/// One reachability probe result.
public struct SMNServerConnectivityResult: Codable {
    public let name: String?
    public let serverStatus: Bool?

    enum CodingKeys: String, CodingKey {
        case name
        case serverStatus = "server_status"
    }
}

/// One port probe result.
public struct SMNPortCheckResult: Codable {
    public let port: Int?
    public let portType: String?
    public let description: String?
    public let portStatus: Bool?

    enum CodingKeys: String, CodingKey {
        case port, description
        case portType = "port_type"
        case portStatus = "port_status"
    }
}

/// One DNS resolution result.
public struct SMNDNSLookupResult: Codable {
    public let dnsIP: String?
    public let alias: String?
    public let reverseDNS: String?

    enum CodingKeys: String, CodingKey {
        case alias
        case dnsIP = "dns_ip"
        case reverseDNS = "reverse_dns"
    }
}

/// Roll-up of the three checks above.
///
/// The three entries do NOT share a type: `serverConnectivity` and `portChecks`
/// are `{status, color}` objects, while `dnsLookup` is a plain array of alias
/// strings.
public struct SMNConnectivitySummary: Codable {
    public let serverConnectivity: SMNStatusColor?
    public let portChecks: SMNStatusColor?
    public let dnsLookup: [String]?

    enum CodingKeys: String, CodingKey {
        case serverConnectivity = "server_connectivity"
        case portChecks = "port_checks"
        case dnsLookup = "dns_lookup"
    }
}

/// A `{status, color}` roll-up pair.
public struct SMNStatusColor: Codable {
    public let status: String?
    public let color: String?
}

/// Firewall / client-isolation / multicast state.
///
/// `value` is the STRING `"Enabled"` or `"Disabled"`, never a boolean. The whole
/// object is `{}` when the state could not be determined.
///
/// `alerts` is an ALERT OBJECT or `{}` — not an array. `clientIsolation` and
/// `multicast` carry the key only when an alert applies.
public struct SMNToggleState: Codable {
    public let value: String?
    public let color: String?
    public let status: String?
    public let alerts: SMNReportAlert?
}

/// A report alert.
///
/// `alertType` is deliberately a String, not an enum — the backend adds members
/// without an API version bump, and a RawRepresentable enum would throw on an
/// unknown value. Branch on `alertType`; never match on `alertValue`, which is a
/// display-ready English string, sometimes templated at runtime.
public struct SMNReportAlert: Codable {
    public let alertType: String?
    public let alertValue: String?

    enum CodingKeys: String, CodingKey {
        case alertType = "alert_type"
        case alertValue = "alert_value"
    }
}
```

- [ ] **Step 4: Wire into `SMNReportPayload`**

Add the property and its coding key:

```swift
    public let basicConnectivity: SMNBasicConnectivity?
    // in CodingKeys:
    case basicConnectivity = "basic_connectivity"
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
xcodebuild test -workspace ScanMyNet.xcworkspace -scheme ScanMyNet \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:ScanMyNetTests/BasicConnectivityTests
```

Expected: PASS, 4 tests.

- [ ] **Step 6: Staging checkpoint (do not commit)**

```bash
git add ScanMyNet/Models/Response/ ScanMyNetTests/
```

Message: `feat(response): add basic connectivity section`

---

### Task 4: Connected devices and router details

**Files:**
- Create: `ScanMyNet/Models/Response/DevicesAndRouter.swift`
- Modify: `ScanMyNet/Models/Response/SMNReportPayload.swift`
- Create: `ScanMyNetTests/DevicesAndRouterTests.swift`

**Interfaces:**
- Consumes: `SMNReportPayload`, `loadFixture`.
- Produces: `SMNLocalConnectedDevice`, `SMNQualityColor`, `SMNDeviceRecognition`, `SMNCustomerRouterDetails`, `AnyCodable`. `SMNQualityColor` is reused by Task 6's `connection_quality`.

> **`AnyCodable` is required here.** `device_details.recognition` is an open
> third-party (Fing) payload. Swift has no built-in `Codable` conformance for
> heterogeneous JSON, unlike Kotlin's `Map<String, Any?>`, so a minimal type
> eraser is introduced in this task.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import ScanMyNet

final class DevicesAndRouterTests: XCTestCase {

    private func report() throws -> SMNReportPayload {
        try JSONDecoder()
            .decode(ReportResponse.self, from: loadFixture("report_response_full"))
            .report!
    }

    func testDeviceDecodesPingStatsAndQualityStruct() throws {
        let device = try report().localConnectedDevices!.first!
        XCTAssertEqual(device.deviceName, "living-room-tv")
        XCTAssertEqual(device.deviceMacAddress, "AA:BB:CC:DD:EE:FF")
        XCTAssertEqual(device.averagePingTime!, 11.95, accuracy: 0.001)
        XCTAssertEqual(device.pingValues!, [12.1, 11.8])
        XCTAssertEqual(device.isSubscriberRouter, false)

        // Distinct from SMNInternetSpeed.connectionQuality: this IS a struct.
        XCTAssertEqual(device.connectionQualityColor?.quality, "good")
        XCTAssertEqual(device.connectionQualityColor?.color, "green")
    }

    func testDeviceRecognitionIsOpenPayload() throws {
        let recognition = try report().localConnectedDevices!.first!.deviceDetails!.recognition!
        XCTAssertEqual(recognition["type"]?.value as? String, "TV")
        XCTAssertEqual(recognition["model"]?.value as? String, "UN55")
    }

    func testRouterDetailsDecode() throws {
        let router = try report().customerRouterDetails!
        XCTAssertEqual(router.make, "Netgear")
        XCTAssertEqual(router.model, "R7000")
        XCTAssertEqual(router.routerIPAddress, "192.168.1.1")
        XCTAssertEqual(
            router.routerDetails?.recognition?["model"]?.value as? String,
            "R7000"
        )
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
xcodebuild test -workspace ScanMyNet.xcworkspace -scheme ScanMyNet \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:ScanMyNetTests/DevicesAndRouterTests
```

Expected: FAIL — no member `localConnectedDevices`.

- [ ] **Step 3: Create `DevicesAndRouter.swift`**

```swift
import Foundation

/// Minimal type eraser for open JSON values.
///
/// Needed because `device_details.recognition` is a third-party (Fing) payload
/// whose contents are not contractual. Decodes the JSON primitives plus nested
/// arrays and objects; anything else decodes as nil rather than throwing.
public struct AnyCodable: Codable {
    public let value: Any?

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = nil
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let bool as Bool: try container.encode(bool)
        case let int as Int: try container.encode(int)
        case let double as Double: try container.encode(double)
        case let string as String: try container.encode(string)
        default: try container.encodeNil()
        }
    }
}

/// A device discovered on the LAN.
///
/// `averagePingTime` is `0` (not nil) when `pingValues` is empty.
/// `deviceDetails` is ABSENT — not null — when device recognition did not run.
public struct SMNLocalConnectedDevice: Codable {
    public let deviceName: String?
    public let deviceIP: String?
    public let deviceMacAddress: String?
    public let manufacturer: String?
    public let packetsDropped: Double?
    public let numPacketsSent: Int?
    public let pingValues: [Double]?
    public let isSubscriberPhone: Bool?
    public let averagePingTime: Double?
    public let connectionQualityColor: SMNQualityColor?
    public let isSubscriberRouter: Bool?
    public let deviceDetails: SMNDeviceRecognition?

    enum CodingKeys: String, CodingKey {
        case manufacturer
        case deviceName = "device_name"
        case deviceIP = "device_ip"
        case deviceMacAddress = "device_mac_address"
        case packetsDropped = "packets_dropped"
        case numPacketsSent = "num_packets_sent"
        case pingValues = "ping_values"
        case isSubscriberPhone = "is_subscriber_phone"
        case averagePingTime = "average_ping_time"
        case connectionQualityColor = "connection_quality_color"
        case isSubscriberRouter = "is_subscriber_router"
        case deviceDetails = "device_details"
    }
}

/// A genuine `{quality, color}` struct.
///
/// Not to be confused with `SMNInternetSpeed.connectionQuality`, which is a
/// single-entry map keyed by the label.
public struct SMNQualityColor: Codable {
    public let quality: String?
    public let color: String?
}

/// Third-party (Fing) device recognition. `recognition` is an open payload.
public struct SMNDeviceRecognition: Codable {
    public let mac: String?
    public let recognition: [String: AnyCodable]?
}

/// Router make, model and identity.
///
/// `routerDetails` is present only when `routerMacAddress` is non-nil.
///
/// The fields `age`, `price_at_launch`, `router_firmware` and `type` were
/// REMOVED from the contract — do not add them back.
public struct SMNCustomerRouterDetails: Codable {
    public let make: String?
    public let model: String?
    public let encryption: String?
    public let protocols: String?
    public let mesh: String?
    public let routerIPAddress: String?
    public let routerMacAddress: String?
    public let manufacturer: String?
    public let hostname: String?
    public let modelDescription: String?
    public let modelNumber: String?
    public let friendlyName: String?
    public let deviceType: String?
    public let routerDetails: SMNDeviceRecognition?

    enum CodingKeys: String, CodingKey {
        case make, model, encryption, protocols, mesh, manufacturer, hostname
        case routerIPAddress = "router_ip_address"
        case routerMacAddress = "router_mac_address"
        case modelDescription = "model_description"
        case modelNumber = "model_number"
        case friendlyName = "friendly_name"
        case deviceType = "device_type"
        case routerDetails = "router_details"
    }
}
```

- [ ] **Step 4: Wire into `SMNReportPayload`**

```swift
    public let localConnectedDevices: [SMNLocalConnectedDevice]?
    public let customerRouterDetails: SMNCustomerRouterDetails?
    // in CodingKeys:
    case localConnectedDevices = "local_connected_devices"
    case customerRouterDetails = "customer_router_details"
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
xcodebuild test -workspace ScanMyNet.xcworkspace -scheme ScanMyNet \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:ScanMyNetTests/DevicesAndRouterTests
```

Expected: PASS, 3 tests.

- [ ] **Step 6: Staging checkpoint (do not commit)**

```bash
git add ScanMyNet/Models/Response/ ScanMyNetTests/
```

Message: `feat(response): add connected devices and router details sections`

---

### Task 5: Topology, wifi network and congestion

**Files:**
- Create: `ScanMyNet/Models/Response/TopologyAndCongestion.swift`
- Modify: `ScanMyNet/Models/Response/SMNReportPayload.swift`
- Create: `ScanMyNetTests/TopologyWifiCongestionTests.swift`

**Interfaces:**
- Consumes: `SMNReportPayload`, `loadFixture`.
- Produces: `SMNNetworkTopology`, `SMNOtherRouterDetail`, `SMNDoubleNat`, `SMNWifiNetworkResult`, `SMNNetworkCongestion`, `SMNUserConnection`, `SMNCongestionEnvironment`, `SMNChannelCongestion`.

- [ ] **Step 1: Write the failing test**

The `index` assertion catches accidental typing of channel congestion as an Int.

```swift
import XCTest
@testable import ScanMyNet

final class TopologyWifiCongestionTests: XCTestCase {

    private func report() throws -> SMNReportPayload {
        try JSONDecoder()
            .decode(ReportResponse.self, from: loadFixture("report_response_full"))
            .report!
    }

    func testTopologyDecodesRoutersAndDoubleNat() throws {
        let topology = try report().networkTopology!
        XCTAssertEqual(topology.routerIPAddress, "192.168.1.1")
        XCTAssertEqual(topology.otherRouters?.count, 3)
        XCTAssertEqual(topology.doubleNatDetected?.isDoubleNat, true)
        XCTAssertEqual(topology.doubleNatDetected?.doubleNatHop, ["10.0.0.1"])

        // The backend builds one detail entry per `other_routers` element, so the
        // two arrays always have equal length. Private hops are labelled
        // "Private" regardless of ASN DB state; public hops stay nil until it is
        // provisioned.
        XCTAssertEqual(topology.otherRoutersDetails?.count, 3)
        XCTAssertEqual(topology.otherRoutersDetails?[0].owner, "Private")
        XCTAssertNil(topology.otherRoutersDetails?[1].owner)
        XCTAssertEqual(topology.otherRoutersDetails?[2].asn, 64500)
        XCTAssertEqual(topology.otherRoutersDetails?[2].owner, "Example ISP")
    }

    func testAbsentDoubleNatDecodesAsNilRatherThanThrowing() throws {
        let json = #"{"data":"u","report":{"network_topology":{"router_ip_address":"192.168.1.1"}}}"#
        let response = try JSONDecoder().decode(ReportResponse.self, from: Data(json.utf8))
        XCTAssertNil(response.report?.networkTopology?.doubleNatDetected)
    }

    func testUserWifiNetworkDecodes() throws {
        let wifi = try report().userWifiNetwork!
        XCTAssertEqual(wifi.ssid, "MyNetwork")
        XCTAssertEqual(wifi.frequency!, 5.0, accuracy: 0.001)
        XCTAssertEqual(wifi.signalStrength, -52)
        XCTAssertEqual(wifi.currentChannel, 44)
    }

    func testChannelCongestionIndexIsAStringNotAnInt() throws {
        let congestion = try report().networkCongestion!
        XCTAssertEqual(congestion.userConnection?.phoneWifiChannel, 44)
        XCTAssertEqual(congestion.environment?.channelCongestion?.first?.index, "6")
        XCTAssertEqual(congestion.environment?.channelCongestion?.first?.numNetworks, 4)
        XCTAssertEqual(
            congestion.environment?.surroundingWifiNetworks?.first?.ssid,
            "Neighbour"
        )
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
xcodebuild test -workspace ScanMyNet.xcworkspace -scheme ScanMyNet \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:ScanMyNetTests/TopologyWifiCongestionTests
```

Expected: FAIL — no member `networkTopology`.

- [ ] **Step 3: Create `TopologyAndCongestion.swift`**

```swift
import Foundation

/// Hop list and double-NAT detection.
///
/// `otherRouters` is de-duplicated and ordered by first appearance across
/// traceroute hops.
public struct SMNNetworkTopology: Codable {
    public let routerIPAddress: String?
    public let otherRouters: [String]?
    public let otherRoutersDetails: [SMNOtherRouterDetail]?
    /// ABSENT ENTIRELY when no double NAT is found — not null, and not
    /// `{is_double_nat: false}`. Treat nil as "no double NAT".
    public let doubleNatDetected: SMNDoubleNat?

    enum CodingKeys: String, CodingKey {
        case routerIPAddress = "router_ip_address"
        case otherRouters = "other_routers"
        case otherRoutersDetails = "other_routers_details"
        case doubleNatDetected = "double_nat_detected"
    }
}

/// One enriched hop.
///
/// Backend builds these as `{'ip': ip, **ASNLookup.lookup_owner(ip)}`, so the
/// wire shape is `{ip, asn, owner}` — `asn` is easy to miss and was initially
/// dropped on Android.
///
/// `owner` is `"Private"` for RFC-1918 addresses regardless of database state;
/// for public addresses it stays nil until the GeoLite2-ASN database is
/// provisioned server-side.
public struct SMNOtherRouterDetail: Codable {
    public let ip: String?
    public let asn: Int?
    public let owner: String?
}

public struct SMNDoubleNat: Codable {
    public let isDoubleNat: Bool?
    public let doubleNatHop: [String]?

    enum CodingKeys: String, CodingKey {
        case isDoubleNat = "is_double_nat"
        case doubleNatHop = "double_nat_hop"
    }
}

/// A WiFi network — the subscriber's own (`user_wifi_network`, `{}` when it
/// could not be identified, typically location permission denied) or a
/// surrounding one, which additionally carries `isSubscriberSSID`.
///
/// `frequency` is in GHz (e.g. `2.4`, `5.0`). `signalStrength` is dBm and
/// therefore negative.
public struct SMNWifiNetworkResult: Codable {
    public let ssid: String?
    public let ssidIP: String?
    public let bssid: String?
    public let encryption: String?
    public let frequency: Double?
    public let wpsAvailability: Bool?
    public let signalStrength: Int?
    public let numWifiChannels: Int?
    public let channelWidth: Int?
    public let currentChannel: Int?
    public let isSubscriberSSID: Bool?

    enum CodingKeys: String, CodingKey {
        case ssid, bssid, encryption, frequency
        case ssidIP = "ssid_ip"
        case wpsAvailability = "wps_availability"
        case signalStrength = "signal_strength"
        case numWifiChannels = "num_wifi_channels"
        case channelWidth = "channel_width"
        case currentChannel = "current_channel"
        case isSubscriberSSID = "is_subscriber_ssid"
    }
}

/// Channel congestion and neighbouring networks. `{}` when no SSIDs submitted.
public struct SMNNetworkCongestion: Codable {
    public let userConnection: SMNUserConnection?
    public let environment: SMNCongestionEnvironment?

    enum CodingKeys: String, CodingKey {
        case userConnection = "user_connection"
        case environment
    }
}

/// The subscriber's own connection.
///
/// `numPhoneWifiChannel` is the COUNT of congestion entries, not a channel
/// number — the actual channel is `phoneWifiChannel`.
public struct SMNUserConnection: Codable {
    public let phoneWifiFrequency: Double?
    public let numPhoneWifiChannel: Int?
    public let numNetworksOnChannel: Int?
    public let phoneWifiChannel: Int?

    enum CodingKeys: String, CodingKey {
        case phoneWifiFrequency = "phone_wifi_frequency"
        case numPhoneWifiChannel = "num_phone_wifi_channel"
        case numNetworksOnChannel = "num_networks_on_channel"
        case phoneWifiChannel = "phone_wifi_channel"
    }
}

/// `surroundingWifiNetworks` excludes the subscriber's own SSID.
public struct SMNCongestionEnvironment: Codable {
    public let channelCongestion: [SMNChannelCongestion]?
    public let surroundingWifiNetworks: [SMNWifiNetworkResult]?

    enum CodingKeys: String, CodingKey {
        case channelCongestion = "channel_congestion"
        case surroundingWifiNetworks = "surrounding_wifi_networks"
    }
}

/// Congestion on one channel.
///
/// `index` is a STRING, not an int.
public struct SMNChannelCongestion: Codable {
    public let index: String?
    public let numNetworks: Int?

    enum CodingKeys: String, CodingKey {
        case index
        case numNetworks = "num_networks"
    }
}
```

- [ ] **Step 4: Wire into `SMNReportPayload`**

```swift
    public let networkTopology: SMNNetworkTopology?
    public let userWifiNetwork: SMNWifiNetworkResult?
    public let networkCongestion: SMNNetworkCongestion?
    // in CodingKeys:
    case networkTopology = "network_topology"
    case userWifiNetwork = "user_wifi_network"
    case networkCongestion = "network_congestion"
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
xcodebuild test -workspace ScanMyNet.xcworkspace -scheme ScanMyNet \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:ScanMyNetTests/TopologyWifiCongestionTests
```

Expected: PASS, 4 tests.

- [ ] **Step 6: Staging checkpoint (do not commit)**

```bash
git add ScanMyNet/Models/Response/ ScanMyNetTests/
```

Message: `feat(response): add topology, wifi network and congestion sections`

---

### Task 6: Connection quality, traceroute, alerts and actions

Completes `SMNReportPayload` — all 15 sections typed.

**Files:**
- Create: `ScanMyNet/Models/Response/QualityAndAlerts.swift`
- Modify: `ScanMyNet/Models/Response/SMNReportPayload.swift`
- Create: `ScanMyNetTests/QualityTracerouteAlertsTests.swift`

**Interfaces:**
- Consumes: `SMNReportPayload`, `SMNQualityColor` (Task 4), `SMNReportAlert` (Task 3), `loadFixture`.
- Produces: `SMNDNSQuality`, `SMNTracerouteResultEntry`, `SMNTracerouteHop`, `SMNReportAction`. Completed `SMNReportPayload`.

> `SMNTracerouteResultEntry` avoids colliding with the existing request-side
> `TracerouteResult` in `ScanMyNet/Models/TracerouteResult.swift`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import ScanMyNet

final class QualityTracerouteAlertsTests: XCTestCase {

    private func report() throws -> SMNReportPayload {
        try JSONDecoder()
            .decode(ReportResponse.self, from: loadFixture("report_response_full"))
            .report!
    }

    func testDNSQualityDecodesJitterAndLayerRanking() throws {
        let quality = try report().connectionQuality!.first!
        XCTAssertEqual(quality.dnsName, "google")
        XCTAssertEqual(quality.jitter!, 0.9, accuracy: 0.001)
        XCTAssertEqual(quality.averagePingTime!, 14.65, accuracy: 0.001)
        XCTAssertEqual(quality.layerRanking, 3)
        XCTAssertEqual(quality.connectionQualityColor?.quality, "good")
    }

    func testTracerouteDecodesHopsWithIntegerRTTs() throws {
        let trace = try report().traceroute!.first!
        XCTAssertEqual(trace.dnsDestinationIP, "8.8.8.8")
        XCTAssertEqual(trace.hops?.first?.dnsName, "router.lan")
        XCTAssertEqual(trace.hops?.first?.rttValues, [1, 2, 1])
    }

    func testAlertsAndActionsUseDifferentFieldNames() throws {
        let r = try report()
        XCTAssertEqual(r.alerts?.first?.alertType, "old_router")
        XCTAssertEqual(r.alerts?.first?.alertValue, "Old Router Model Detected")
        XCTAssertEqual(r.actions?.first?.actionType, "download_speed")
        XCTAssertEqual(r.actions?.first?.actionValue, "Download speed")
    }

    func testUnknownAlertTypeDecodesAsPlainString() throws {
        let json = #"{"data":"u","report":{"alerts":[{"alert_type":"brand_new_type","alert_value":"x"}]}}"#
        let response = try JSONDecoder().decode(ReportResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.report?.alerts?.first?.alertType, "brand_new_type")
    }

    func testIncompleteAnalysisDecodes() throws {
        XCTAssertEqual(try report().incompleteAnalysis, false)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
xcodebuild test -workspace ScanMyNet.xcworkspace -scheme ScanMyNet \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:ScanMyNetTests/QualityTracerouteAlertsTests
```

Expected: FAIL — no member `connectionQuality`.

- [ ] **Step 3: Create `QualityAndAlerts.swift`**

```swift
import Foundation

/// Per-DNS ping result.
///
/// `layerRanking` is `1` (local), `2` (unknown/default) or `3` (external). The
/// entry with `isSubscriberRouter` true is the subscriber's own router, useful
/// for separating in-home from outside-home quality.
public struct SMNDNSQuality: Codable {
    public let dnsName: String?
    public let dnsIP: String?
    public let packetsDropped: Double?
    public let numPacketsSent: Int?
    public let pingValues: [Double]?
    public let isSubscriberRouter: Bool?
    public let jitter: Double?
    public let averagePingTime: Double?
    public let connectionQualityColor: SMNQualityColor?
    public let layerRanking: Int?

    enum CodingKeys: String, CodingKey {
        case jitter
        case dnsName = "dns_name"
        case dnsIP = "dns_ip"
        case packetsDropped = "packets_dropped"
        case numPacketsSent = "num_packets_sent"
        case pingValues = "ping_values"
        case isSubscriberRouter = "is_subscriber_router"
        case averagePingTime = "average_ping_time"
        case connectionQualityColor = "connection_quality_color"
        case layerRanking = "layer_ranking"
    }
}

/// Raw traceroute, passed through unmodified from the request.
public struct SMNTracerouteResultEntry: Codable {
    public let dnsDestinationIP: String?
    public let hops: [SMNTracerouteHop]?

    enum CodingKeys: String, CodingKey {
        case hops
        case dnsDestinationIP = "dns_destination_ip"
    }
}

/// `rttValues` are integers in milliseconds. `dnsName` is nullable.
public struct SMNTracerouteHop: Codable {
    public let dnsIP: String?
    public let dnsName: String?
    public let rttValues: [Int]?

    enum CodingKeys: String, CodingKey {
        case dnsIP = "dns_ip"
        case dnsName = "dns_name"
        case rttValues = "rtt_values"
    }
}

/// A report recommendation.
///
/// NOTE the field names differ from `SMNReportAlert`: actions use `action_*`,
/// alerts use `alert_*`. They are not `type` / `message`, and the two types are
/// not interchangeable.
///
/// `actionType` is deliberately a String, not an enum — members are added
/// without an API version bump. Branch on `actionType`; never match on
/// `actionValue`, which is a display string, sometimes templated at runtime.
public struct SMNReportAction: Codable {
    public let actionType: String?
    public let actionValue: String?

    enum CodingKeys: String, CodingKey {
        case actionType = "action_type"
        case actionValue = "action_value"
    }
}
```

- [ ] **Step 4: Complete `SMNReportPayload`**

Replace the whole file:

```swift
import Foundation

/// The full report payload returned alongside the hosted report URL.
///
/// All 15 section keys are always present in the JSON, but every one is
/// modelled optional: the parent `report` object itself is optional, and an
/// absent parent makes every child absent.
///
/// This mirrors the frontend contract and evolves with it — it is NOT a stable
/// versioned schema.
public struct SMNReportPayload: Codable {
    public let customerDetails: SMNCustomerDetails?
    public let sdkDetails: SMNSDKDetails?
    public let routerUsageDuringScan: SMNRouterUsage?
    public let customerInternetSpeed: SMNInternetSpeed?
    public let basicConnectivity: SMNBasicConnectivity?
    public let localConnectedDevices: [SMNLocalConnectedDevice]?
    public let customerRouterDetails: SMNCustomerRouterDetails?
    public let networkTopology: SMNNetworkTopology?
    public let userWifiNetwork: SMNWifiNetworkResult?
    public let networkCongestion: SMNNetworkCongestion?
    public let connectionQuality: [SMNDNSQuality]?
    public let traceroute: [SMNTracerouteResultEntry]?
    public let alerts: [SMNReportAlert]?
    public let actions: [SMNReportAction]?
    public let incompleteAnalysis: Bool?

    enum CodingKeys: String, CodingKey {
        case traceroute, alerts, actions
        case customerDetails = "customer_details"
        case sdkDetails = "sdk_details"
        case routerUsageDuringScan = "router_usage_during_scan"
        case customerInternetSpeed = "customer_internet_speed"
        case basicConnectivity = "basic_connectivity"
        case localConnectedDevices = "local_connected_devices"
        case customerRouterDetails = "customer_router_details"
        case networkTopology = "network_topology"
        case userWifiNetwork = "user_wifi_network"
        case networkCongestion = "network_congestion"
        case connectionQuality = "connection_quality"
        case incompleteAnalysis = "incomplete_analysis"
    }
}
```

- [ ] **Step 5: Run the full suite**

```bash
xcodebuild test -workspace ScanMyNet.xcworkspace -scheme ScanMyNet \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

Expected: PASS — all sections plus the Task 1 minimal-response regression guard.

- [ ] **Step 6: Staging checkpoint (do not commit)**

```bash
git add ScanMyNet/Models/Response/ ScanMyNetTests/
```

Message: `feat(response): add quality, traceroute, alerts and actions sections`

---

### Task 7: Thread the payload through the delegate chain

The models now decode but the payload is still discarded — `ReportManager` passes only the URL onward. This task connects it to the public API. **This has no Android equivalent**, where the DTO already reaches the plugin bridge.

**Files:**
- Modify: `ScanMyNet/ReportManager.swift` (protocol + `sendReport`)
- Modify: `ScanMyNet/ScanMyNet.swift` (public protocol + extension)
- Create: `ScanMyNetTests/DelegateThreadingTests.swift`

**Interfaces:**
- Consumes: `ReportResponse`, `SMNReportPayload`.
- Produces: `ScanMyNetDelegate.scanFinished(reportUrl:report:)` — defaulted, non-breaking. This is the method the Flutter plugin bridge implements in Plan 3.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import ScanMyNet

/// Verifies the defaulted protocol method does not break existing conformers.
final class DelegateThreadingTests: XCTestCase {

    /// Implements ONLY the original method — must still compile and run.
    final class LegacyDelegate: ScanMyNetDelegate {
        var receivedURL: String?
        func scanStarted() {}
        func scanFinished(reportUrl: String) { receivedURL = reportUrl }
        func nextScanStarted(value: String) {}
        func scanProgress(value: Float) {}
        func scanServiceFailed(type: String, with error: Error) {}
        func scanFailed(with error: Error, response: String) {}
        func scanCanceled() {}
        func serviceTriggered(log: String) {}
        func getRequestData(request: URLRequest?, response: HTTPURLResponse?, error: Error?) {}
    }

    /// Implements the new method too.
    final class ModernDelegate: LegacyDelegateBase {
        var receivedReport: SMNReportPayload?
        func scanFinished(reportUrl: String, report: SMNReportPayload?) {
            receivedReport = report
        }
    }

    func testLegacyDelegateStillCompilesAndReceivesURL() {
        let delegate = LegacyDelegate()
        delegate.scanFinished(reportUrl: "https://example.test/report")
        XCTAssertEqual(delegate.receivedURL, "https://example.test/report")
    }

    func testDefaultImplementationForwardsToLegacyMethod() {
        let delegate = LegacyDelegate()
        // The defaulted method must fall through to the URL-only variant so
        // existing conformers keep receiving the completion signal.
        delegate.scanFinished(reportUrl: "https://example.test/report", report: nil)
        XCTAssertEqual(delegate.receivedURL, "https://example.test/report")
    }
}

typealias LegacyDelegateBase = DelegateThreadingTests.LegacyDelegate
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
xcodebuild test -workspace ScanMyNet.xcworkspace -scheme ScanMyNet \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:ScanMyNetTests/DelegateThreadingTests
```

Expected: FAIL — `incorrect argument label in call (have 'reportUrl:report:', expected 'reportUrl:')`.

- [ ] **Step 3: Extend the public protocol**

In `ScanMyNet/ScanMyNet.swift`, add the method to `ScanMyNetDelegate` and provide the default. The default forwarding to the URL-only variant is what makes this non-breaking.

```swift
public protocol ScanMyNetDelegate {
    func scanStarted()
    func scanFinished(reportUrl: String)
    /// Called with the full report payload alongside the hosted report URL.
    ///
    /// Defaulted so existing conformers that implement only
    /// `scanFinished(reportUrl:)` keep compiling and keep receiving the
    /// completion signal. `report` is nil when the backend omitted the payload
    /// or it failed to decode.
    func scanFinished(reportUrl: String, report: SMNReportPayload?)
    func nextScanStarted(value: String)
    func scanProgress(value: Float)
    func scanServiceFailed(type: String, with error: Error)
    func scanFailed(with error: Error, response: String)
    func scanCanceled()

    func serviceTriggered(log: String)
    func getRequestData(request: URLRequest?, response: HTTPURLResponse?, error: Error?)
}

public extension ScanMyNetDelegate {
    func scanFinished(reportUrl: String, report: SMNReportPayload?) {
        scanFinished(reportUrl: reportUrl)
    }
}
```

- [ ] **Step 4: Carry the payload through `ReportManager`**

In `ScanMyNet/ReportManager.swift`, widen the internal delegate:

```swift
protocol ReportManagerDelegate {
    func reportSentSuccessfully(url: String, report: SMNReportPayload?)
    func sendReportFailed(error: Error, response: String)

    func getRequestData(request: URLRequest?, response: HTTPURLResponse?, error: Error?)
}
```

And in `sendReport()`, pass the decoded payload through:

```swift
                do {
                    let object = try JSONDecoder().decode(ReportResponse.self, from: data)
                    self.delegate?.reportSentSuccessfully(
                        url: self.buildReportUrl(from: object.data),
                        report: object.report
                    )
                } catch {
                    let json = String(data: data, encoding: String.Encoding.utf8)
                    self.delegate?.sendReportFailed(error: error, response: json ?? error.localizedDescription)
                }
```

- [ ] **Step 5: Forward from `ScanMyNetManager`**

In `ScanMyNet/ScanMyNet.swift`, in the `ReportManagerDelegate` extension:

```swift
    func reportSentSuccessfully(url: String, report: SMNReportPayload?) {
        delegate?.scanFinished(reportUrl: url, report: report)
    }
```

Calling only the two-argument form is correct: conformers that implement just
`scanFinished(reportUrl:)` reach it through the protocol extension's default.

- [ ] **Step 6: Run the test to verify it passes**

```bash
xcodebuild test -workspace ScanMyNet.xcworkspace -scheme ScanMyNet \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

Expected: PASS — full suite.

- [ ] **Step 7: Verify the Example app still compiles**

The Example app conforms to `ScanMyNetDelegate` and must not need changes — that is the whole point of defaulting the new method.

```bash
xcodebuild build -workspace ScanMyNet.xcworkspace -scheme ScanMyNet \
  -destination 'generic/platform=iOS Simulator'
```

Expected: BUILD SUCCEEDED with no changes to `Example/ViewController.swift`.

- [ ] **Step 8: Staging checkpoint (do not commit)**

```bash
git add ScanMyNet/ReportManager.swift ScanMyNet/ScanMyNet.swift ScanMyNetTests/
```

Message: `feat(delegate): surface report payload via defaulted scanFinished`

---

### Task 8: Build the xcframework and install it into the Flutter plugin

Produces the artifact Plan 3 consumes.

**Files:**
- Modify: `ScanMyNet.podspec:9`
- Modify (generated output): `scanmynet_sdk/ios/ScanMyNet.xcframework/`

**Interfaces:**
- Consumes: completed `SMNReportPayload` and delegate chain from Tasks 6-7.
- Produces: a rebuilt `ScanMyNet.xcframework` exposing `SMNReportPayload` and `scanFinished(reportUrl:report:)`.

- [ ] **Step 1: Bump the podspec version**

In `ScanMyNet.podspec`, line 9:

```ruby
  s.version = "1.1.0"
```

- [ ] **Step 2: Build the xcframework**

```bash
cd ~/path/to/scanmynet-ios
./build.sh
```

Expected: `--- Built build/ScanMyNet.xcframework`.

The script archives device and simulator slices with `CODE_SIGNING_ALLOWED=NO` and combines them via `xcodebuild -create-xcframework`.

- [ ] **Step 3: Verify the new API is in the built interface**

This is the check that catches a stale build — the single most likely failure mode, since a cached archive produces a framework that looks fine but lacks the new symbols.

```bash
grep -c "SMNReportPayload" \
  build/ScanMyNet.xcframework/ios-arm64/ScanMyNet.framework/Modules/ScanMyNet.swiftmodule/arm64-apple-ios.swiftinterface
grep "scanFinished" \
  build/ScanMyNet.xcframework/ios-arm64/ScanMyNet.framework/Modules/ScanMyNet.swiftmodule/arm64-apple-ios.swiftinterface
```

Expected: a non-zero `SMNReportPayload` count, and **both** `scanFinished(reportUrl:)` and `scanFinished(reportUrl:report:)` present.

If only the one-argument form appears, the build was stale — `rm -rf build/` and re-run `./build.sh`.

- [ ] **Step 4: Install into the Flutter plugin**

```bash
DEST="../scanmynet_sdk/ios/ScanMyNet.xcframework"
rm -rf "$DEST"
cp -R build/ScanMyNet.xcframework "$DEST"
```

- [ ] **Step 5: Verify the plugin still builds**

```bash
cd ../scanmynet_sdk/example
flutter build ios --debug --no-codesign
```

Expected: BUILD SUCCESSFUL. The bridge does not implement the new delegate method yet — that is Plan 3 — so this only proves the framework is well-formed and the existing conformance still compiles, which is the defaulting behaviour working as intended.

- [ ] **Step 6: Staging checkpoint (do not commit)**

In `scanmynet-ios`:

```bash
git add ScanMyNet.podspec
```

Message: `chore: bump podspec to 1.1.0 for report response payload`

In `scanmynet_sdk`:

```bash
git add ios/ScanMyNet.xcframework
```

Message: `chore(ios): update ScanMyNet.xcframework with report response payload`

> **Keep a copy of the previous xcframework** until Plan 3 is verified
> end-to-end — it is the rollback path, and unlike the Android AAR it is not
> preserved under a separate version directory. `git stash` or a copy outside
> the repo both work.

---

## Definition of Done

- [ ] `ScanMyNetTests` target exists and runs
- [ ] All 15 sections typed; `SMNReportPayload` complete
- [ ] `xcodebuild test` passes on the full suite
- [ ] Minimal `{"data": "..."}` response still decodes (Task 1 regression guard)
- [ ] A delegate implementing only `scanFinished(reportUrl:)` still compiles (Task 7)
- [ ] Example app compiles unchanged
- [ ] Rebuilt xcframework's `.swiftinterface` exposes `SMNReportPayload` and both `scanFinished` overloads
- [ ] `flutter build ios --debug --no-codesign` succeeds in `scanmynet_sdk/example`
- [ ] All work staged, nothing committed, pending owner approval

## Notes for the implementer

**Why optionality is load-bearing, not stylistic.** `ReportManager.sendReport()` catches a decode throw and calls `sendReportFailed`, which surfaces as `scanFailed`. Swift `Codable` throws on a missing non-optional key. So a single non-optional field the backend happens to omit would convert every successful scan into a reported failure — a total outage from one type annotation. Every property in `Models/Response/` is optional for this reason.

**Why not `.convertFromSnakeCase`.** It would remove most of the `CodingKeys` boilerplate, but `customer_details.last_known_public_ip_details` has capitalised keys (`Country`, `Region`, `ISP`) that do not round-trip through it. The existing `Report` type already uses explicit `CodingKeys` with a plain `JSONDecoder()`, so this also matches the codebase convention.

**Type-name collisions.** `ScanMyNet/Models/` already contains request-side `ServerConnectivity`, `PortCheck`, `DNSLookup` and `TracerouteResult`. The response types deliberately take different names (`…Result`, `SMNTracerouteResultEntry`) rather than shadowing them. Do not attempt to reuse the request types — beyond the naming clash, their shapes differ.

**Keep the fixture byte-identical to Android's.** Both SDKs assert against the same JSON. If you need to change the fixture, change it in both repos in the same session, or the two platforms will silently drift apart.
