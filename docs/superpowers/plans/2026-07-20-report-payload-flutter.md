# Report Payload — Flutter Plugin & Publication (Plan 3 of 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Carry the full 15-section report payload from both rebuilt native SDKs into Dart through Pigeon, expose it on `ScanCompleted`, and prepare the package for publication.

**Architecture:** ~33 Pigeon classes mirror the report sections and generate into Kotlin, Swift and Dart. Both native bridges map their platform DTOs onto the Pigeon types; irregular JSON shapes are normalised in the bridges so they never reach the schema. Dart adds open-enum wrappers over the string alert/action types and a version handshake guarding Pigeon's positional codecs.

**Tech Stack:** Pigeon 26.3.4, Dart/Flutter, Kotlin, Swift.

**Repo:** `C:\Users\abdal\BitBucket\scanmynet_sdk`

**Spec:** `docs/superpowers/specs/2026-07-20-report-payload-and-publish-design.md`

> ## ⚠️ Prerequisites — this plan is blocked until both are true
>
> - **Plan 1 complete:** `tools-1.1.aar` in `android/local-maven-repo/`, and
>   `android/build.gradle.kts:83` referencing `1.1`.
> - **Plan 2 complete:** rebuilt `ios/ScanMyNet.xcframework` whose
>   `.swiftinterface` exposes `ReportPayload` and `scanFinished(reportUrl:report:)`.
>
> Tasks 1, 4, 5 and 7 can be written and unit-tested without the binaries.
> Tasks 2, 3 and 6 cannot compile without them.
>
> **Task 8 (publication) is additionally gated on the project owner** resolving
> the license and rotating the API key. Do not run `pub publish` without explicit
> approval.

## Global Constraints

- **Append-only Pigeon fields.** Pigeon codecs are positional — the generated `_toList()` in `lib/src/messages.g.dart` encodes by index, not name. Adding a field mid-class silently shifts every subsequent field's meaning across the boundary. Always append.
- **`ScanResult.reportUrl` stays field 0** and keeps its type and meaning. It is the shipped contract.
- **`alertType` / `actionType` are `String` in Pigeon.** Never Pigeon enums — those throw on unrecognised wire values, and the backend adds members without an API version bump. Openness is added in Dart.
- **Never use `.convertFromSnakeCase`-style blanket key mapping.** Irregular shapes (capitalised geo keys, the single-entry quality map) are normalised in the native bridges.
- **Regenerate Pigeon after every schema edit:** `dart run pigeon --input pigeons/messages.dart`. Never hand-edit `messages.g.dart`, `Messages.g.kt` or `Messages.g.swift`.
- **Do not commit.** The project owner has held all commits across all three repos. Each task ends with a staging checkpoint.
- **Do not run `pub publish`** until the owner confirms the license is in place.

---

### Task 1: Pigeon schema for all 15 sections

**Files:**
- Modify: `pigeons/messages.dart`
- Regenerated: `lib/src/messages.g.dart`, `android/src/main/kotlin/com/creativeadvtech/scanmynet_sdk/Messages.g.kt`, `ios/scanmynet_sdk/Sources/scanmynet_sdk/Messages.g.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `ReportData` and 32 nested classes; `ScanResult` gains `reportId`, `customerId`, `report`.

- [ ] **Step 1: Append the report classes to the schema**

Add to `pigeons/messages.dart`, after the existing `ScanReport` class. Note the
name is `ReportData`, **not** `ScanReport` — the latter already exists and
carries the *request* payload (`ReportParamDto`), an unrelated thing.

```dart
// ---------------------------------------------------------------------------
// REPORT PAYLOAD (response) — mirrors POST /report/ `report` object.
//
// NOTE: this is the RESPONSE report. `ScanReport` above is the REQUEST payload
// that was submitted. They are different objects; do not merge them.
//
// Every field is nullable: sections are built from whatever the scan submitted,
// and several keys are absent entirely rather than null.
// ---------------------------------------------------------------------------

/// A `{quality, color}` pair. NOT the same shape as
/// [InternetSpeed.connectionQuality], which is a single-entry map.
class QualityColor {
  QualityColor({this.quality, this.color});
  String? quality;
  String? color;
}

/// A `{status, color}` roll-up pair.
class StatusColor {
  StatusColor({this.status, this.color});
  String? status;
  String? color;
}

/// A report alert. [alertType] is a String, never an enum — new members ship
/// without an API version bump. Branch on [alertType], never [alertValue].
class ReportAlert {
  ReportAlert({this.alertType, this.alertValue});
  String? alertType;
  String? alertValue;
}

/// A report recommendation. Field names differ from [ReportAlert]:
/// actions use `action_*`, alerts use `alert_*`.
class ReportAction {
  ReportAction({this.actionType, this.actionValue});
  String? actionType;
  String? actionValue;
}

class CustomerDetails {
  CustomerDetails({this.key, this.lastKnownPublicIp, this.lastKnownPublicIpDetails});
  String? key;
  String? lastKnownPublicIp;
  /// Capitalised keys (`Country`, `Region`, `ISP`). Passed through verbatim.
  Map<String, String>? lastKnownPublicIpDetails;
}

class SdkDetails {
  SdkDetails({
    this.start, this.duration, this.platform, this.app, this.routeThisSdk,
    this.userPublicUpAddress, this.gpsLatitude, this.gpsLongitude,
  });
  String? start;
  /// Seconds.
  int? duration;
  String? platform;
  String? app;
  String? routeThisSdk;
  String? userPublicUpAddress;
  double? gpsLatitude;
  double? gpsLongitude;
}

/// Mbps.
class RouterUsage {
  RouterUsage({this.networkUsageDown, this.networkUsageUp});
  double? networkUsageDown;
  double? networkUsageUp;
}

class InternetSpeed {
  InternetSpeed({
    this.networkSpeedDown, this.networkSpeedUp, this.currentNegotiatedLinkSpeed,
    this.maximumLinkSupportedByPhone, this.networkSpeedUpSegments,
    this.networkSpeedDownSegments, this.connectionQuality,
  });
  double? networkSpeedDown;
  double? networkSpeedUp;
  double? currentNegotiatedLinkSpeed;
  String? maximumLinkSupportedByPhone;
  List<double>? networkSpeedUpSegments;
  List<double>? networkSpeedDownSegments;
  /// SINGLE-ENTRY map keyed by the quality label, e.g. `{"good": "green"}`.
  /// NOT a [QualityColor] struct.
  Map<String, String>? connectionQuality;
}

class ServerConnectivityResult {
  ServerConnectivityResult({this.name, this.serverStatus});
  String? name;
  bool? serverStatus;
}

class PortCheckResult {
  PortCheckResult({this.port, this.portType, this.description, this.portStatus});
  int? port;
  String? portType;
  String? description;
  bool? portStatus;
}

class DnsLookupResult {
  DnsLookupResult({this.dnsIp, this.alias, this.reverseDns});
  String? dnsIp;
  String? alias;
  String? reverseDns;
}

/// The three entries do NOT share a type: [dnsLookup] is a list of alias
/// strings while its siblings are objects.
class ConnectivitySummary {
  ConnectivitySummary({this.serverConnectivity, this.portChecks, this.dnsLookup});
  StatusColor? serverConnectivity;
  StatusColor? portChecks;
  List<String>? dnsLookup;
}

/// Firewall / client isolation / multicast. [value] is the STRING
/// `"Enabled"` / `"Disabled"`, never a bool.
class ToggleState {
  ToggleState({this.value, this.color, this.status, this.alert});
  String? value;
  String? color;
  String? status;
  /// Single alert object, not a list. Null when no alert applies.
  ReportAlert? alert;
}

class BasicConnectivity {
  BasicConnectivity({
    this.ipAssignedViaDhcp, this.serverConnectivity, this.portChecks,
    this.dnsLookup, this.summary, this.blockedServers, this.blockedUdpPorts,
    this.blockedTcpPorts, this.firewall, this.clientIsolation, this.multicast,
  });
  bool? ipAssignedViaDhcp;
  List<ServerConnectivityResult>? serverConnectivity;
  List<PortCheckResult>? portChecks;
  List<DnsLookupResult>? dnsLookup;
  ConnectivitySummary? summary;
  /// Blocked server names (payload key `servers`).
  List<String>? blockedServers;
  /// Blocked UDP ports (payload key `udp`).
  List<int>? blockedUdpPorts;
  /// Blocked TCP ports (payload key `tcp`).
  List<int>? blockedTcpPorts;
  ToggleState? firewall;
  ToggleState? clientIsolation;
  ToggleState? multicast;
  // NOTE: the payload's `basic_connectivity.alerts` is always empty — real
  // alerts are promoted to ReportData.alerts. Deliberately not modelled.
}

/// Third-party (Fing) recognition. [recognition] is an open payload.
class DeviceRecognition {
  DeviceRecognition({this.mac, this.recognition});
  String? mac;
  Map<String, Object?>? recognition;
}

class LocalConnectedDevice {
  LocalConnectedDevice({
    this.deviceName, this.deviceIp, this.deviceMacAddress, this.manufacturer,
    this.packetsDropped, this.numPacketsSent, this.pingValues,
    this.isSubscriberPhone, this.averagePingTime, this.connectionQualityColor,
    this.isSubscriberRouter, this.deviceDetails,
  });
  String? deviceName;
  String? deviceIp;
  String? deviceMacAddress;
  String? manufacturer;
  double? packetsDropped;
  int? numPacketsSent;
  List<double>? pingValues;
  bool? isSubscriberPhone;
  /// `0` (not null) when [pingValues] is empty.
  double? averagePingTime;
  QualityColor? connectionQualityColor;
  bool? isSubscriberRouter;
  /// Null when device recognition did not run.
  DeviceRecognition? deviceDetails;
}

class CustomerRouterDetails {
  CustomerRouterDetails({
    this.make, this.model, this.encryption, this.protocols, this.mesh,
    this.routerIpAddress, this.routerMacAddress, this.manufacturer,
    this.hostname, this.modelDescription, this.modelNumber, this.friendlyName,
    this.deviceType, this.routerDetails,
  });
  String? make;
  String? model;
  String? encryption;
  String? protocols;
  String? mesh;
  String? routerIpAddress;
  String? routerMacAddress;
  String? manufacturer;
  String? hostname;
  String? modelDescription;
  String? modelNumber;
  String? friendlyName;
  String? deviceType;
  /// Present only when [routerMacAddress] is non-null.
  DeviceRecognition? routerDetails;
}

class OtherRouterDetail {
  OtherRouterDetail({this.ip, this.asn, this.owner});
  String? ip;
  /// Autonomous system number. Null for private hops and until the GeoLite2-ASN
  /// database is provisioned server-side.
  int? asn;
  /// `"Private"` for RFC-1918 addresses regardless of database state; null for
  /// public addresses until the ASN database is provisioned.
  String? owner;
}

class DoubleNat {
  DoubleNat({this.isDoubleNat, this.doubleNatHop});
  bool? isDoubleNat;
  List<String>? doubleNatHop;
}

class NetworkTopology {
  NetworkTopology({
    this.routerIpAddress, this.otherRouters, this.otherRoutersDetails,
    this.doubleNatDetected,
  });
  String? routerIpAddress;
  /// De-duplicated, ordered by first appearance across traceroute hops.
  List<String>? otherRouters;
  List<OtherRouterDetail>? otherRoutersDetails;
  /// Null means NO double NAT — the key is absent in that case, not false.
  DoubleNat? doubleNatDetected;
}

/// [frequency] is GHz. [signalStrength] is dBm (negative).
class WifiNetworkResult {
  WifiNetworkResult({
    this.ssid, this.ssidIp, this.bssid, this.encryption, this.frequency,
    this.wpsAvailability, this.signalStrength, this.numWifiChannels,
    this.channelWidth, this.currentChannel, this.isSubscriberSsid,
  });
  String? ssid;
  String? ssidIp;
  String? bssid;
  String? encryption;
  double? frequency;
  bool? wpsAvailability;
  int? signalStrength;
  int? numWifiChannels;
  int? channelWidth;
  int? currentChannel;
  bool? isSubscriberSsid;
}

/// [numPhoneWifiChannel] is the COUNT of congestion entries, not a channel
/// number — the channel is [phoneWifiChannel].
class UserConnection {
  UserConnection({
    this.phoneWifiFrequency, this.numPhoneWifiChannel,
    this.numNetworksOnChannel, this.phoneWifiChannel,
  });
  double? phoneWifiFrequency;
  int? numPhoneWifiChannel;
  int? numNetworksOnChannel;
  int? phoneWifiChannel;
}

/// [index] is a STRING in the payload, not an int.
class ChannelCongestion {
  ChannelCongestion({this.index, this.numNetworks});
  String? index;
  int? numNetworks;
}

class CongestionEnvironment {
  CongestionEnvironment({this.channelCongestion, this.surroundingWifiNetworks});
  List<ChannelCongestion>? channelCongestion;
  /// Excludes the subscriber's own SSID.
  List<WifiNetworkResult>? surroundingWifiNetworks;
}

class NetworkCongestion {
  NetworkCongestion({this.userConnection, this.environment});
  UserConnection? userConnection;
  CongestionEnvironment? environment;
}

/// [layerRanking] is 1 (local), 2 (unknown/default) or 3 (external).
class DnsQuality {
  DnsQuality({
    this.dnsName, this.dnsIp, this.packetsDropped, this.numPacketsSent,
    this.pingValues, this.isSubscriberRouter, this.jitter, this.averagePingTime,
    this.connectionQualityColor, this.layerRanking,
  });
  String? dnsName;
  String? dnsIp;
  double? packetsDropped;
  int? numPacketsSent;
  List<double>? pingValues;
  /// True for the subscriber's own router.
  bool? isSubscriberRouter;
  double? jitter;
  double? averagePingTime;
  QualityColor? connectionQualityColor;
  int? layerRanking;
}

/// [rttValues] are integers in milliseconds.
class TracerouteHop {
  TracerouteHop({this.dnsIp, this.dnsName, this.rttValues});
  String? dnsIp;
  String? dnsName;
  List<int>? rttValues;
}

class TracerouteEntry {
  TracerouteEntry({this.dnsDestinationIp, this.hops});
  String? dnsDestinationIp;
  List<TracerouteHop>? hops;
}

/// The full report payload. Mirrors the FE contract and evolves with it — this
/// is NOT a stable versioned schema.
class ReportData {
  ReportData({
    this.customerDetails, this.sdkDetails, this.routerUsageDuringScan,
    this.customerInternetSpeed, this.basicConnectivity,
    this.localConnectedDevices, this.customerRouterDetails, this.networkTopology,
    this.userWifiNetwork, this.networkCongestion, this.connectionQuality,
    this.traceroute, this.alerts, this.actions, this.incompleteAnalysis,
  });
  CustomerDetails? customerDetails;
  SdkDetails? sdkDetails;
  RouterUsage? routerUsageDuringScan;
  InternetSpeed? customerInternetSpeed;
  BasicConnectivity? basicConnectivity;
  List<LocalConnectedDevice>? localConnectedDevices;
  CustomerRouterDetails? customerRouterDetails;
  NetworkTopology? networkTopology;
  WifiNetworkResult? userWifiNetwork;
  NetworkCongestion? networkCongestion;
  List<DnsQuality>? connectionQuality;
  List<TracerouteEntry>? traceroute;
  List<ReportAlert>? alerts;
  List<ReportAction>? actions;
  /// True when both `missing_upnp` and `incomplete_speed_test` fired — present
  /// the scan as unreliable.
  bool? incompleteAnalysis;
}
```

- [ ] **Step 2: Append the three fields to `ScanResult`**

Append only — never insert. Positional codecs make field order the wire format.

```dart
class ScanResult {
  ScanResult({
    required this.reportUrl,
    this.status,
    this.totalDurationMs,
    this.reportId,
    this.customerId,
    this.report,
  });

  String reportUrl;
  ScanResultStatus? status;
  int? totalDurationMs;

  /// Backend report identifier. Lets you correlate a scan without parsing the
  /// JWT in [reportUrl]. Null on backends predating the payload.
  String? reportId;

  /// Subscriber/customer key the report was filed under.
  String? customerId;

  /// The full report payload. Null when the backend omitted it.
  ReportData? report;
}
```

- [ ] **Step 3: Regenerate**

```bash
cd "C:/Users/abdal/BitBucket/scanmynet_sdk"
dart run pigeon --input pigeons/messages.dart
```

Expected: no errors; three generated files updated.

- [ ] **Step 4: Verify generation and field order**

```bash
dart analyze lib/
grep -n "class ReportData" lib/src/messages.g.dart
grep -n "reportUrl\|reportId\|customerId" lib/src/messages.g.dart | head -20
```

Expected: `dart analyze` clean; `ReportData` present; within `ScanResult`, `reportUrl` still appears **before** `reportId` / `customerId` in `_toList()`.

- [ ] **Step 5: Confirm existing Dart tests still pass**

```bash
flutter test
```

Expected: PASS — the existing suite in `test/scanmynet_sdk_test.dart` is unaffected.

- [ ] **Step 6: Staging checkpoint (do not commit)**

```bash
git add pigeons/messages.dart lib/src/messages.g.dart \
        android/src/main/kotlin/com/creativeadvtech/scanmynet_sdk/Messages.g.kt \
        ios/scanmynet_sdk/Sources/scanmynet_sdk/Messages.g.swift
```

Message: `feat(pigeon): add report payload schema for all 15 sections`

---

### Task 2: Android bridge mapping

**Requires Plan 1 complete.**

**Files:**
- Create: `android/src/main/kotlin/com/creativeadvtech/scanmynet_sdk/ReportMapper.kt`
- Modify: `android/src/main/kotlin/com/creativeadvtech/scanmynet_sdk/ScanHostApiImpl.kt:118-122`
- Create: `android/src/test/kotlin/com/creativeadvtech/scanmynet_sdk/ReportMapperTest.kt`

**Interfaces:**
- Consumes: `ReportDto` (Plan 1), Pigeon `ReportData` (Task 1).
- Produces: `ReportDto.toPigeon(): ReportData` and the widened `ReportResponseDto.toPigeon(...)`.

> Mapping lives in its own file rather than `ScanHostApiImpl`. That file is
> already ~170 lines of lifecycle logic; ~33 mappers would swamp it.

- [ ] **Step 1: Write the failing test**

```kotlin
package com.creativeadvtech.scanmynet_sdk

import com.creative.tools.rest.dto.response.ChannelCongestionDto
import com.creative.tools.rest.dto.response.CustomerDetailsDto
import com.creative.tools.rest.dto.response.InternetSpeedDto
import com.creative.tools.rest.dto.response.ReportDto
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ReportMapperTest {

    @Test
    fun `maps capitalised geo keys through unchanged`() {
        val dto = ReportDto(
            customer_details = CustomerDetailsDto(
                key = "acme-key",
                last_known_public_ip = "203.0.113.10",
                last_known_public_ip_details = mapOf("Country" to "US", "ISP" to "Example ISP"),
            ),
        )

        val pigeon = dto.toPigeon()

        assertEquals("acme-key", pigeon.customerDetails!!.key)
        assertEquals("US", pigeon.customerDetails!!.lastKnownPublicIpDetails!!["Country"])
        assertEquals("Example ISP", pigeon.customerDetails!!.lastKnownPublicIpDetails!!["ISP"])
    }

    @Test
    fun `maps single entry quality map without flattening it`() {
        val dto = ReportDto(
            customer_internet_speed = InternetSpeedDto(
                network_speed_down = 87.4,
                connection_quality = mapOf("good" to "green"),
            ),
        )

        val quality = dto.toPigeon().customerInternetSpeed!!.connectionQuality!!

        assertEquals(1, quality.size)
        assertEquals("green", quality["good"])
    }

    @Test
    fun `null sections map to null rather than empty objects`() {
        val pigeon = ReportDto().toPigeon()
        assertNull(pigeon.customerDetails)
        assertNull(pigeon.networkTopology)
        assertNull(pigeon.basicConnectivity)
    }

    @Test
    fun `channel congestion index stays a string`() {
        val dto = ChannelCongestionDto(index = "6", num_networks = 4)
        assertEquals("6", dto.toPigeon().index)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd "C:/Users/abdal/BitBucket/scanmynet_sdk/android"
../example/android/gradlew -p . :test --tests "*ReportMapperTest*"
```

(Or run from `example/android` with `./gradlew :scanmynet_sdk:testDebugUnitTest`.)

Expected: FAIL — unresolved reference `toPigeon`.

- [ ] **Step 3: Write `ReportMapper.kt`**

```kotlin
package com.creativeadvtech.scanmynet_sdk

import com.creative.tools.rest.dto.response.*

/**
 * Maps the SDK's response DTOs onto the Pigeon report types.
 *
 * Null in, null out: an absent section stays absent rather than becoming an
 * empty object, so Dart can distinguish "not measured" from "measured empty".
 */
internal fun ReportDto.toPigeon() = ReportData(
    customerDetails = customer_details?.toPigeon(),
    sdkDetails = sdk_details?.toPigeon(),
    routerUsageDuringScan = router_usage_during_scan?.toPigeon(),
    customerInternetSpeed = customer_internet_speed?.toPigeon(),
    basicConnectivity = basic_connectivity?.toPigeon(),
    localConnectedDevices = local_connected_devices?.map { it.toPigeon() },
    customerRouterDetails = customer_router_details?.toPigeon(),
    networkTopology = network_topology?.toPigeon(),
    userWifiNetwork = user_wifi_network?.toPigeon(),
    networkCongestion = network_congestion?.toPigeon(),
    connectionQuality = connection_quality?.map { it.toPigeon() },
    traceroute = traceroute?.map { it.toPigeon() },
    alerts = alerts?.map { it.toPigeon() },
    actions = actions?.map { it.toPigeon() },
    incompleteAnalysis = incomplete_analysis,
)

internal fun CustomerDetailsDto.toPigeon() = CustomerDetails(
    key = key,
    lastKnownPublicIp = last_known_public_ip,
    // Capitalised keys pass through verbatim — no case transformation.
    lastKnownPublicIpDetails = last_known_public_ip_details,
)

internal fun SdkDetailsDto.toPigeon() = SdkDetails(
    start = start,
    duration = duration,
    platform = platform,
    app = app,
    routeThisSdk = route_this_sdk,
    userPublicUpAddress = user_public_up_address,
    gpsLatitude = gps_latitude,
    gpsLongitude = gps_longitude,
)

internal fun RouterUsageDto.toPigeon() = RouterUsage(
    networkUsageDown = network_usage_down,
    networkUsageUp = network_usage_up,
)

internal fun InternetSpeedDto.toPigeon() = InternetSpeed(
    networkSpeedDown = network_speed_down,
    networkSpeedUp = network_speed_up,
    currentNegotiatedLinkSpeed = current_negotiated_link_speed,
    maximumLinkSupportedByPhone = maximum_link_supported_by_phone,
    networkSpeedUpSegments = network_speed_up_segments,
    networkSpeedDownSegments = network_speed_down_segments,
    // Single-entry map keyed by label — passed through as-is, NOT flattened.
    connectionQuality = connection_quality,
)

internal fun BasicConnectivityDto.toPigeon() = BasicConnectivity(
    ipAssignedViaDhcp = ip_assigned_via_dhcp,
    serverConnectivity = server_connectivity?.map { it.toPigeon() },
    portChecks = port_checks?.map { it.toPigeon() },
    dnsLookup = dns_lookup?.map { it.toPigeon() },
    summary = summary?.toPigeon(),
    blockedServers = servers,
    blockedUdpPorts = udp,
    blockedTcpPorts = tcp,
    firewall = firewall?.toPigeon(),
    clientIsolation = client_isolation?.toPigeon(),
    multicast = multicast?.toPigeon(),
    // basic_connectivity.alerts is always empty — intentionally dropped.
)

internal fun ServerConnectivityResultDto.toPigeon() =
    ServerConnectivityResult(name = name, serverStatus = server_status)

internal fun PortCheckDto.toPigeon() = PortCheckResult(
    port = port, portType = port_type, description = description, portStatus = port_status,
)

internal fun DnsLookupResultDto.toPigeon() =
    DnsLookupResult(dnsIp = dns_ip, alias = alias, reverseDns = reverse_dns)

internal fun ConnectivitySummaryDto.toPigeon() = ConnectivitySummary(
    serverConnectivity = server_connectivity?.toPigeon(),
    portChecks = port_checks?.toPigeon(),
    dnsLookup = dns_lookup,
)

internal fun StatusColorDto.toPigeon() = StatusColor(status = status, color = color)

internal fun ToggleStateDto.toPigeon() = ToggleState(
    value = value, color = color, status = status, alert = alerts?.toPigeon(),
)

internal fun AlertDto.toPigeon() =
    ReportAlert(alertType = alert_type, alertValue = alert_value)

internal fun ActionDto.toPigeon() =
    ReportAction(actionType = action_type, actionValue = action_value)

internal fun LocalConnectedDeviceDto.toPigeon() = LocalConnectedDevice(
    deviceName = device_name,
    deviceIp = device_ip,
    deviceMacAddress = device_mac_address,
    manufacturer = manufacturer,
    packetsDropped = packets_dropped,
    numPacketsSent = num_packets_sent,
    pingValues = ping_values,
    isSubscriberPhone = is_subscriber_phone,
    averagePingTime = average_ping_time,
    connectionQualityColor = connection_quality_color?.toPigeon(),
    isSubscriberRouter = is_subscriber_router,
    deviceDetails = device_details?.toPigeon(),
)

internal fun QualityColorDto.toPigeon() = QualityColor(quality = quality, color = color)

internal fun DeviceRecognitionDto.toPigeon() =
    DeviceRecognition(mac = mac, recognition = recognition)

internal fun CustomerRouterDetailsDto.toPigeon() = CustomerRouterDetails(
    make = make, model = model, encryption = encryption, protocols = protocols,
    mesh = mesh, routerIpAddress = router_ip_address,
    routerMacAddress = router_mac_address, manufacturer = manufacturer,
    hostname = hostname, modelDescription = model_description,
    modelNumber = model_number, friendlyName = friendly_name,
    deviceType = device_type, routerDetails = router_details?.toPigeon(),
)

internal fun NetworkTopologyDto.toPigeon() = NetworkTopology(
    routerIpAddress = router_ip_address,
    otherRouters = other_routers,
    otherRoutersDetails = other_routers_details?.map { it.toPigeon() },
    doubleNatDetected = double_nat_detected?.toPigeon(),
)

internal fun OtherRouterDetailDto.toPigeon() =
    OtherRouterDetail(ip = ip, asn = asn, owner = owner)

internal fun DoubleNatDto.toPigeon() =
    DoubleNat(isDoubleNat = is_double_nat, doubleNatHop = double_nat_hop)

internal fun WifiNetworkResultDto.toPigeon() = WifiNetworkResult(
    ssid = ssid, ssidIp = ssid_ip, bssid = bssid, encryption = encryption,
    frequency = frequency, wpsAvailability = wps_availability,
    signalStrength = signal_strength, numWifiChannels = num_wifi_channels,
    channelWidth = channel_width, currentChannel = current_channel,
    isSubscriberSsid = is_subscriber_ssid,
)

internal fun NetworkCongestionDto.toPigeon() = NetworkCongestion(
    userConnection = user_connection?.toPigeon(),
    environment = environment?.toPigeon(),
)

internal fun UserConnectionDto.toPigeon() = UserConnection(
    phoneWifiFrequency = phone_wifi_frequency,
    numPhoneWifiChannel = num_phone_wifi_channel,
    numNetworksOnChannel = num_networks_on_channel,
    phoneWifiChannel = phone_wifi_channel,
)

internal fun CongestionEnvironmentDto.toPigeon() = CongestionEnvironment(
    channelCongestion = channel_congestion?.map { it.toPigeon() },
    surroundingWifiNetworks = surrounding_wifi_networks?.map { it.toPigeon() },
)

/** [ChannelCongestionDto.index] is a String and stays one. */
internal fun ChannelCongestionDto.toPigeon() =
    ChannelCongestion(index = index, numNetworks = num_networks)

internal fun DnsQualityDto.toPigeon() = DnsQuality(
    dnsName = dns_name, dnsIp = dns_ip, packetsDropped = packets_dropped,
    numPacketsSent = num_packets_sent, pingValues = ping_values,
    isSubscriberRouter = is_subscriber_router, jitter = jitter,
    averagePingTime = average_ping_time,
    connectionQualityColor = connection_quality_color?.toPigeon(),
    layerRanking = layer_ranking,
)

internal fun TracerouteResultDto.toPigeon() = TracerouteEntry(
    dnsDestinationIp = dns_destination_ip,
    hops = hops?.map { it.toPigeon() },
)

internal fun TracerouteHopDto.toPigeon() =
    TracerouteHop(dnsIp = dns_ip, dnsName = dns_name, rttValues = rtt_values)
```

- [ ] **Step 4: Wire into `ScanHostApiImpl`**

Replace lines 118-122:

```kotlin
    private fun ReportResponseDto.toPigeon(result: NetworkScanResult?) = ScanResult(
        reportUrl = buildReportUrl(data),
        status = result?.status?.toPigeon() ?: ScanResultStatus.SUCCESS,
        totalDurationMs = result?.duration,
        reportId = report_id,
        customerId = customer_id,
        report = report?.toPigeon(),
    )
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
cd "C:/Users/abdal/BitBucket/scanmynet_sdk/example/android"
./gradlew :scanmynet_sdk:testDebugUnitTest --tests "*ReportMapperTest*"
```

Expected: PASS, 4 tests.

- [ ] **Step 6: Build the example app**

```bash
cd "C:/Users/abdal/BitBucket/scanmynet_sdk/example"
flutter build apk --debug
```

Expected: BUILD SUCCESSFUL.

- [ ] **Step 7: Staging checkpoint (do not commit)**

```bash
git add android/src/main/kotlin/ android/src/test/kotlin/
```

Message: `feat(android): map report response DTOs onto Pigeon types`

---

### Task 3: iOS bridge mapping

**Requires Plan 2 complete.** Execute on macOS.

**Files:**
- Create: `ios/scanmynet_sdk/Sources/scanmynet_sdk/ReportMapper.swift`
- Modify: `ios/scanmynet_sdk/Sources/scanmynet_sdk/ScanHostApiImpl.swift:97-100`

**Interfaces:**
- Consumes: `ReportPayload` (Plan 2), Pigeon `ReportData` (Task 1).
- Produces: `ReportPayload.toPigeon() -> ReportData`.

- [ ] **Step 1: Write `ReportMapper.swift`**

There is no unit-test target in the plugin's iOS module; correctness is covered
by Task 6's end-to-end run and by the shared fixture asserted in Plans 1-2.

```swift
import Foundation
import ScanMyNet

/// Maps the SDK's response models onto the Pigeon report types.
///
/// Nil in, nil out: an absent section stays absent rather than becoming an
/// empty object, so Dart can distinguish "not measured" from "measured empty".
extension SMNReportPayload {
  func toPigeon() -> ReportData {
    ReportData(
      customerDetails: customerDetails?.toPigeon(),
      sdkDetails: sdkDetails?.toPigeon(),
      routerUsageDuringScan: routerUsageDuringScan?.toPigeon(),
      customerInternetSpeed: customerInternetSpeed?.toPigeon(),
      basicConnectivity: basicConnectivity?.toPigeon(),
      localConnectedDevices: localConnectedDevices?.map { $0.toPigeon() },
      customerRouterDetails: customerRouterDetails?.toPigeon(),
      networkTopology: networkTopology?.toPigeon(),
      userWifiNetwork: userWifiNetwork?.toPigeon(),
      networkCongestion: networkCongestion?.toPigeon(),
      connectionQuality: connectionQuality?.map { $0.toPigeon() },
      traceroute: traceroute?.map { $0.toPigeon() },
      alerts: alerts?.map { $0.toPigeon() },
      actions: actions?.map { $0.toPigeon() },
      incompleteAnalysis: incompleteAnalysis
    )
  }
}

extension SMNCustomerDetails {
  func toPigeon() -> CustomerDetails {
    // Capitalised keys pass through verbatim — no case transformation.
    CustomerDetails(
      key: key,
      lastKnownPublicIp: lastKnownPublicIP,
      lastKnownPublicIpDetails: lastKnownPublicIPDetails
    )
  }
}

extension SMNSDKDetails {
  func toPigeon() -> SdkDetails {
    SdkDetails(
      start: start, duration: duration.map(Int64.init), platform: platform,
      app: app, routeThisSdk: routeThisSDK,
      userPublicUpAddress: userPublicUpAddress,
      gpsLatitude: gpsLatitude, gpsLongitude: gpsLongitude
    )
  }
}

extension SMNRouterUsage {
  func toPigeon() -> RouterUsage {
    RouterUsage(
      networkUsageDown: networkUsageDown, networkUsageUp: networkUsageUp
    )
  }
}

extension SMNInternetSpeed {
  func toPigeon() -> InternetSpeed {
    // Single-entry map keyed by label — passed through as-is, NOT flattened.
    InternetSpeed(
      networkSpeedDown: networkSpeedDown,
      networkSpeedUp: networkSpeedUp,
      currentNegotiatedLinkSpeed: currentNegotiatedLinkSpeed,
      maximumLinkSupportedByPhone: maximumLinkSupportedByPhone,
      networkSpeedUpSegments: networkSpeedUpSegments,
      networkSpeedDownSegments: networkSpeedDownSegments,
      connectionQuality: connectionQuality
    )
  }
}

extension SMNBasicConnectivity {
  func toPigeon() -> BasicConnectivity {
    BasicConnectivity(
      ipAssignedViaDhcp: ipAssignedViaDHCP,
      serverConnectivity: serverConnectivity?.map { $0.toPigeon() },
      portChecks: portChecks?.map { $0.toPigeon() },
      dnsLookup: dnsLookup?.map { $0.toPigeon() },
      summary: summary?.toPigeon(),
      blockedServers: servers,
      blockedUdpPorts: udp?.map(Int64.init),
      blockedTcpPorts: tcp?.map(Int64.init),
      firewall: firewall?.toPigeon(),
      clientIsolation: clientIsolation?.toPigeon(),
      multicast: multicast?.toPigeon()
      // basic_connectivity.alerts is always empty — intentionally dropped.
    )
  }
}

extension SMNServerConnectivityResult {
  func toPigeon() -> ServerConnectivityResult {
    ServerConnectivityResult(name: name, serverStatus: serverStatus)
  }
}

extension SMNPortCheckResult {
  func toPigeon() -> PortCheckResult {
    PortCheckResult(
      port: port.map(Int64.init), portType: portType,
      description: description, portStatus: portStatus
    )
  }
}

extension SMNDNSLookupResult {
  func toPigeon() -> DnsLookupResult {
    DnsLookupResult(dnsIp: dnsIP, alias: alias, reverseDns: reverseDNS)
  }
}

extension SMNConnectivitySummary {
  func toPigeon() -> ConnectivitySummary {
    ConnectivitySummary(
      serverConnectivity: serverConnectivity?.toPigeon(),
      portChecks: portChecks?.toPigeon(),
      dnsLookup: dnsLookup
    )
  }
}

extension SMNStatusColor {
  func toPigeon() -> StatusColor {
    StatusColor(status: status, color: color)
  }
}

extension SMNToggleState {
  func toPigeon() -> ToggleState {
    ToggleState(
      value: value, color: color, status: status, alert: alerts?.toPigeon()
    )
  }
}

extension SMNReportAlert {
  func toPigeon() -> ReportAlert {
    ReportAlert(alertType: alertType, alertValue: alertValue)
  }
}

extension SMNReportAction {
  func toPigeon() -> ReportAction {
    ReportAction(actionType: actionType, actionValue: actionValue)
  }
}

extension SMNLocalConnectedDevice {
  func toPigeon() -> LocalConnectedDevice {
    LocalConnectedDevice(
      deviceName: deviceName, deviceIp: deviceIP,
      deviceMacAddress: deviceMacAddress, manufacturer: manufacturer,
      packetsDropped: packetsDropped,
      numPacketsSent: numPacketsSent.map(Int64.init),
      pingValues: pingValues, isSubscriberPhone: isSubscriberPhone,
      averagePingTime: averagePingTime,
      connectionQualityColor: connectionQualityColor?.toPigeon(),
      isSubscriberRouter: isSubscriberRouter,
      deviceDetails: deviceDetails?.toPigeon()
    )
  }
}

extension SMNQualityColor {
  func toPigeon() -> QualityColor {
    QualityColor(quality: quality, color: color)
  }
}

extension SMNDeviceRecognition {
  func toPigeon() -> DeviceRecognition {
    // AnyCodable is unwrapped to its underlying value for the channel.
    DeviceRecognition(
      mac: mac,
      recognition: recognition?.mapValues { $0.value }
    )
  }
}

extension SMNCustomerRouterDetails {
  func toPigeon() -> CustomerRouterDetails {
    CustomerRouterDetails(
      make: make, model: model, encryption: encryption, protocols: protocols,
      mesh: mesh, routerIpAddress: routerIPAddress,
      routerMacAddress: routerMacAddress, manufacturer: manufacturer,
      hostname: hostname, modelDescription: modelDescription,
      modelNumber: modelNumber, friendlyName: friendlyName,
      deviceType: deviceType, routerDetails: routerDetails?.toPigeon()
    )
  }
}

extension SMNNetworkTopology {
  func toPigeon() -> NetworkTopology {
    NetworkTopology(
      routerIpAddress: routerIPAddress,
      otherRouters: otherRouters,
      otherRoutersDetails: otherRoutersDetails?.map { $0.toPigeon() },
      doubleNatDetected: doubleNatDetected?.toPigeon()
    )
  }
}

extension SMNOtherRouterDetail {
  func toPigeon() -> OtherRouterDetail {
    OtherRouterDetail(ip: ip, asn: asn.map(Int64.init), owner: owner)
  }
}

extension SMNDoubleNat {
  func toPigeon() -> DoubleNat {
    DoubleNat(isDoubleNat: isDoubleNat, doubleNatHop: doubleNatHop)
  }
}

extension SMNWifiNetworkResult {
  func toPigeon() -> WifiNetworkResult {
    WifiNetworkResult(
      ssid: ssid, ssidIp: ssidIP, bssid: bssid, encryption: encryption,
      frequency: frequency, wpsAvailability: wpsAvailability,
      signalStrength: signalStrength.map(Int64.init),
      numWifiChannels: numWifiChannels.map(Int64.init),
      channelWidth: channelWidth.map(Int64.init),
      currentChannel: currentChannel.map(Int64.init),
      isSubscriberSsid: isSubscriberSSID
    )
  }
}

extension SMNNetworkCongestion {
  func toPigeon() -> NetworkCongestion {
    NetworkCongestion(
      userConnection: userConnection?.toPigeon(),
      environment: environment?.toPigeon()
    )
  }
}

extension SMNUserConnection {
  func toPigeon() -> UserConnection {
    UserConnection(
      phoneWifiFrequency: phoneWifiFrequency,
      numPhoneWifiChannel: numPhoneWifiChannel.map(Int64.init),
      numNetworksOnChannel: numNetworksOnChannel.map(Int64.init),
      phoneWifiChannel: phoneWifiChannel.map(Int64.init)
    )
  }
}

extension SMNCongestionEnvironment {
  func toPigeon() -> CongestionEnvironment {
    CongestionEnvironment(
      channelCongestion: channelCongestion?.map { $0.toPigeon() },
      surroundingWifiNetworks: surroundingWifiNetworks?.map { $0.toPigeon() }
    )
  }
}

extension SMNChannelCongestion {
  /// `index` is a String and stays one.
  func toPigeon() -> ChannelCongestion {
    ChannelCongestion(
      index: index, numNetworks: numNetworks.map(Int64.init)
    )
  }
}

extension SMNDNSQuality {
  func toPigeon() -> DnsQuality {
    DnsQuality(
      dnsName: dnsName, dnsIp: dnsIP, packetsDropped: packetsDropped,
      numPacketsSent: numPacketsSent.map(Int64.init), pingValues: pingValues,
      isSubscriberRouter: isSubscriberRouter, jitter: jitter,
      averagePingTime: averagePingTime,
      connectionQualityColor: connectionQualityColor?.toPigeon(),
      layerRanking: layerRanking.map(Int64.init)
    )
  }
}

extension SMNTracerouteResultEntry {
  func toPigeon() -> TracerouteEntry {
    TracerouteEntry(
      dnsDestinationIp: dnsDestinationIP,
      hops: hops?.map { $0.toPigeon() }
    )
  }
}

extension SMNTracerouteHop {
  func toPigeon() -> TracerouteHop {
    TracerouteHop(
      dnsIp: dnsIP, dnsName: dnsName, rttValues: rttValues?.map(Int64.init)
    )
  }
}
```

> **Why the framework types carry an `SMN` prefix.** Pigeon's Swift generator
> emits **unprefixed** type names — `SwiftOptions` has no prefix option, and the
> existing `Messages.g.swift` confirms it (`struct ScanConfig`, `struct
> ScanResult`). So Task 1 generates a bare `ReportAlert`, `CustomerDetails`,
> `QualityColor` and so on *into this plugin module*.
>
> Those are exactly the names the framework's response models would otherwise
> have. Swift resolves a bare name to the local module first, so
> `extension ReportAlert { func toPigeon() -> ReportAlert }` would extend the
> Pigeon type and recurse into itself rather than converting anything — a
> confusing failure, not an obvious one. Plan 2 therefore names the framework
> types `SMN…`, which makes every line below unambiguous: the extension target
> is the framework type, the return type is the Pigeon type.

- [ ] **Step 2: Implement the new delegate method**

In `ScanHostApiImpl.swift`, replace `scanFinished(reportUrl:)` (lines 97-100):

```swift
  func scanFinished(reportUrl: String) {
    // Superseded by the payload-carrying variant below. Kept so the protocol's
    // default implementation is never the one that runs.
    scanFinished(reportUrl: reportUrl, report: nil)
  }

  func scanFinished(reportUrl: String, report: ReportPayload?) {
    let result = ScanResult(
      reportUrl: reportUrl,
      status: .success,
      report: report?.toPigeon()
    )
    onMain { self.flutterApi.onFinished(result: result) { _ in } }
  }
```

> `reportId` / `customerId` are not available on iOS: the SDK's
> `reportSentSuccessfully` carries only the URL and payload. If Earthlink needs
> them on iOS, Plan 2 Task 7 must also thread `response.reportId` /
> `response.customerId` through. Left out here to keep the delegate change
> minimal; revisit if the requirement firms up.

- [ ] **Step 3: Build the example app**

```bash
cd "C:/Users/abdal/BitBucket/scanmynet_sdk/example"
flutter build ios --debug --no-codesign
```

Expected: BUILD SUCCESSFUL.

- [ ] **Step 4: Staging checkpoint (do not commit)**

```bash
git add ios/scanmynet_sdk/Sources/scanmynet_sdk/
```

Message: `feat(ios): map report payload onto Pigeon types`

---

### Task 4: Dart open enums and public surface

**Files:**
- Create: `lib/src/report_types.dart`
- Modify: `lib/scanmynet_sdk.dart:6-7`
- Create: `test/report_types_test.dart`

**Interfaces:**
- Consumes: Pigeon `ReportAlert`, `ReportAction`, `ScanResult`.
- Produces: `AlertType`, `ActionType` open enums; extensions `ReportAlert.type`, `ReportAction.type`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scanmynet_sdk/scanmynet_sdk.dart';

void main() {
  test('known alert type resolves to its enum member', () {
    final alert = ReportAlert(alertType: 'old_router', alertValue: 'Old Router');
    expect(alert.type, AlertType.oldRouter);
  });

  test('unknown alert type falls back to unknown and keeps the raw value', () {
    final alert = ReportAlert(alertType: 'brand_new_type', alertValue: 'x');
    expect(alert.type, AlertType.unknown);
    expect(alert.alertType, 'brand_new_type');
  });

  test('null alert type resolves to unknown', () {
    expect(ReportAlert().type, AlertType.unknown);
  });

  test('known action type resolves to its enum member', () {
    final action = ReportAction(actionType: 'download_speed', actionValue: 'x');
    expect(action.type, ActionType.downloadSpeed);
  });

  test('unknown action type falls back to unknown', () {
    expect(ReportAction(actionType: 'nope').type, ActionType.unknown);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/report_types_test.dart
```

Expected: FAIL — `AlertType` undefined.

- [ ] **Step 3: Write `lib/src/report_types.dart`**

```dart
import 'messages.g.dart';

/// Known `alert_type` values, as an OPEN enum.
///
/// The backend adds members without an API version bump, so anything
/// unrecognised resolves to [unknown] rather than throwing. The raw string
/// stays available on [ReportAlert.alertType].
enum AlertType {
  firewall('firewall'),
  missingUpnp('missing_upnp'),
  doubleNat('double_nat'),
  incompleteSpeedTest('incomplete_speed_test'),
  incompleteScan('incomplete_scan'),
  missingLocation('missing_location'),
  oldRouter('old_router'),
  networkUtilizationAlert('network_utilization_alert'),
  multicastDisabled('multicast_disabled'),
  clientIsolationEnabled('client_isolation_enabled'),
  highNetworkUtilization('high_network_utilization'),
  duplicateSsid('duplicate_ssid'),
  rangeExtender('range_extender'),
  meshNetwork('mesh_network'),
  networkSpeedLoss('network_speed_loss'),

  /// A value this SDK version does not know. Read the raw string instead.
  unknown('');

  const AlertType(this.wireValue);

  /// The `alert_type` string as sent by the backend.
  final String wireValue;

  static AlertType fromWire(String? value) => AlertType.values.firstWhere(
        (t) => t.wireValue == value,
        orElse: () => AlertType.unknown,
      );
}

/// Known `action_type` values, as an OPEN enum. See [AlertType].
enum ActionType {
  incompleteSpeedtest('incomplete_speedtest'),
  highRouterUsageScan('high_router_usage_scan'),
  downloadSpeed('download_speed'),
  closerToTheRouter('closer_to_the_router'),
  connectedTo2ghzNetwork('connected_to_2ghz_network'),
  recommendedChannel('recommended_channel'),

  /// A value this SDK version does not know. Read the raw string instead.
  unknown('');

  const ActionType(this.wireValue);

  /// The `action_type` string as sent by the backend.
  final String wireValue;

  static ActionType fromWire(String? value) => ActionType.values.firstWhere(
        (t) => t.wireValue == value,
        orElse: () => ActionType.unknown,
      );
}

/// Branch on [type], never on `alertValue` — values are display-ready English
/// strings, some templated at runtime, and are not stable identifiers.
extension ReportAlertType on ReportAlert {
  AlertType get type => AlertType.fromWire(alertType);
}

/// Branch on [type], never on `actionValue`. See [ReportAlertType].
extension ReportActionType on ReportAction {
  ActionType get type => ActionType.fromWire(actionType);
}
```

- [ ] **Step 4: Export it**

In `lib/scanmynet_sdk.dart`, after line 7:

```dart
export 'src/report_types.dart';
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
flutter test test/report_types_test.dart
```

Expected: PASS, 5 tests.

- [ ] **Step 6: Staging checkpoint (do not commit)**

```bash
git add lib/src/report_types.dart lib/scanmynet_sdk.dart test/report_types_test.dart
```

Message: `feat(dart): add open enums for alert and action types`

---

### Task 5: Version handshake

Guards Pigeon's positional codecs. Without it a Dart/native version mismatch
misreads fields by index and serves corrupted scan data with no error.

**Files:**
- Modify: `pigeons/messages.dart` (`ScanConfig`)
- Modify: `android/.../ScanHostApiImpl.kt` (`configure`)
- Modify: `ios/.../ScanHostApiImpl.swift` (`configure`)
- Modify: `lib/scanmynet_sdk.dart` (`configure`)
- Modify: `test/scanmynet_sdk_test.dart`

**Interfaces:**
- Consumes: `ScanConfig`.
- Produces: `ScanConfig.schemaVersion` (appended field) and a `SCHEMA_VERSION` constant in all three languages.

- [ ] **Step 1: Append the field to `ScanConfig`**

```dart
  /// Pigeon schema version, set by the Dart layer. Native compares it against
  /// its own compiled-in constant and throws on mismatch — codecs are
  /// positional, so a skewed pair misreads fields silently rather than failing.
  int? schemaVersion;
```

Regenerate:

```bash
dart run pigeon --input pigeons/messages.dart
```

- [ ] **Step 2: Send it from Dart**

In `lib/scanmynet_sdk.dart`:

```dart
  /// Pigeon schema version. Bump whenever fields are added to the schema.
  static const int schemaVersion = 2;

  Future<void> configure(ScanConfig config) {
    config.schemaVersion = schemaVersion;
    return _host.configure(config);
  }
```

- [ ] **Step 3: Check it on Android**

At the top of `ScanHostApiImpl.configure`:

```kotlin
        val incoming = config.schemaVersion
        if (incoming != null && incoming != SCHEMA_VERSION) {
            throw IllegalStateException(
                "Pigeon schema mismatch: Dart sent v$incoming, native expects " +
                    "v$SCHEMA_VERSION. Codecs are positional — a mismatched pair " +
                    "misreads fields silently. Rebuild the plugin's native binaries.",
            )
        }
```

And in the companion object:

```kotlin
    companion object {
        /** Must match `.schemaVersion` in Dart. */
        const val SCHEMA_VERSION = 2L
    }
```

- [ ] **Step 4: Check it on iOS**

At the top of `ScanHostApiImpl.configure`:

```swift
    if let incoming = config.schemaVersion, incoming != Self.schemaVersion {
      throw PigeonError(
        code: "SCHEMA_MISMATCH",
        message: "Pigeon schema mismatch: Dart sent v\(incoming), native expects "
          + "v\(Self.schemaVersion). Codecs are positional — a mismatched pair "
          + "misreads fields silently. Rebuild the plugin's native binaries.",
        details: nil
      )
    }
```

And as a static member of `ScanHostApiImpl`:

```swift
  /// Must match `.schemaVersion` in Dart.
  private static let schemaVersion: Int64 = 2
```

- [ ] **Step 5: Add the test**

Append to `test/scanmynet_sdk_test.dart`:

```dart
  test('configure stamps the schema version onto the config', () async {
    final config = ScanConfig(apiKey: 'key');
    await sdk.configure(config);
    expect(fake.configuredWith!.schemaVersion, .schemaVersion);
  });
```

- [ ] **Step 6: Run the tests**

```bash
flutter test
```

Expected: PASS — full suite.

- [ ] **Step 7: Staging checkpoint (do not commit)**

```bash
git add pigeons/ lib/ android/src/main/kotlin/ ios/scanmynet_sdk/Sources/ test/
```

Message: `feat: add Pigeon schema version handshake`

---

### Task 6: Example app renders the report

**Requires Tasks 2 and 3 complete.** This is the end-to-end proof.

**Files:**
- Create: `example/lib/ui/features/scan/views/widgets/report_summary_card.dart`
- Modify: `example/lib/ui/features/scan/view_models/scan_view_model.dart`
- Modify: `example/lib/ui/features/scan/views/scan_page.dart`

**Interfaces:**
- Consumes: `ScanCompleted`, `ScanResult.report`, `AlertType`, `ActionType`.
- Produces: `ReportSummaryCard` widget.

- [ ] **Step 1: Expose the report on the view model**

In `scan_view_model.dart`, alongside the existing completion handling, retain
the payload:

```dart
  ReportData? _report;

  /// The full report payload from the last completed scan, if the backend
  /// supplied one. Null on older backends.
  ReportData? get report => _report;
```

And where `ScanCompleted` is handled, add:

```dart
      case ScanCompleted(:final result):
        _report = result.report;
```

- [ ] **Step 2: Write the summary card**

```dart
import 'package:flutter/material.dart';
import 'package:scanmynet_sdk/scanmynet_sdk.dart';

/// Renders the headline sections of a completed report.
///
/// Demonstrates the two shapes that are easy to get wrong: the single-entry
/// quality map on speed, and branching on `type` rather than the display value.
class ReportSummaryCard extends StatelessWidget {
  const ReportSummaryCard({super.key, required this.report});

  final ReportData report;

  @override
  Widget build(BuildContext context) {
    final speed = report.customerInternetSpeed;
    // Single-entry map keyed by the quality label — read the first entry.
    final quality = speed?.connectionQuality?.entries.firstOrNull;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (speed != null)
              Text(
                'Down ${speed.networkSpeedDown ?? '—'} Mbps  •  '
                'Up ${speed.networkSpeedUp ?? '—'} Mbps'
                '${quality != null ? '  •  ${quality.key}' : ''}',
              ),
            Text('Devices: ${report.localConnectedDevices?.length ?? 0}'),
            if (report.incompleteAnalysis == true)
              const Text(
                'Scan incomplete — results may be unreliable.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            const SizedBox(height: 8),
            // Branch on `type`, never on the display value.
            for (final alert in report.alerts ?? <ReportAlert>[])
              Text('⚠ ${alert.alertValue ?? alert.alertType} (${alert.type.name})'),
            for (final action in report.actions ?? <ReportAction>[])
              Text('→ ${action.actionValue ?? action.actionType}'),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Show it on the scan page**

In `scan_page.dart`, where the report link card is rendered, add below it:

```dart
            if (viewModel.report != null)
              ReportSummaryCard(report: viewModel.report!),
```

- [ ] **Step 4: Run a real scan on each platform**

```bash
cd example
flutter run   # Android device
flutter run   # iOS device
```

Expected on both: the scan completes, the hosted-report link still appears
(proving `data` is unbroken), and the summary card renders live values.

- [ ] **Step 5: Staging checkpoint (do not commit)**

```bash
git add example/lib/
```

Message: `feat(example): render report summary from the scan payload`

---

### Task 7: Package metadata and documentation

**Files:**
- Modify: `pubspec.yaml`
- Modify: `CHANGELOG.md`
- Modify: `README.md`
- Modify: `example/lib/app.dart:21`
- Create: `example/README.md`

**Interfaces:**
- Consumes: everything above.
- Produces: a package that passes `flutter pub publish --dry-run`.

- [ ] **Step 1: Remove the committed API key**

`example/lib/app.dart:21` contains a live credential. Replace the literal with
a build-time define:

```dart
  // Supply your ScanMyNet credentials at build time:
  //   flutter run --dart-define=SMN_API_KEY=your-key
  // The report request returns 401 without a valid key.
  static const _apiKey = String.fromEnvironment('SMN_API_KEY');

  late final ScanViewModel _viewModel = ScanViewModel(
    apiKey: _apiKey,
    requestKey: 'QA-KEY',
    appName: 'ScanMyNet',
    environment: ScanEnvironment.dev,
  );
```

> **The owner must still rotate the old key.** It is in git history, so removing
> it from the working tree does not un-compromise it.

- [ ] **Step 2: Document the flag**

Create `example/README.md`:

```markdown
# scanmynet_sdk example

Demonstrates configuring the SDK, running a scan, and rendering the report.

## Running

An API key is required — the report request returns 401 without one:

```bash
flutter run --dart-define=SMN_API_KEY=your-key
```

Contact ScanMyNet for credentials. Never commit a key to source control.
```

- [ ] **Step 3: Fill in the package metadata**

In `pubspec.yaml`, replace the first five lines:

```yaml
name: scanmynet_sdk
description: "Flutter plugin for the ScanMyNet network diagnostics SDK — runs a full home-network scan and returns a structured report."
version: 1.0.0
homepage: https://bitbucket.org/creativeadvtech/scanmynet_sdk
repository: https://bitbucket.org/creativeadvtech/scanmynet_sdk
```

- [ ] **Step 4: Write the changelog**

Replace `CHANGELOG.md`:

```markdown
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
```

- [ ] **Step 5: Write the README**

Replace `README.md` with install, setup, usage and payload guidance. It must
cover: adding the dependency; Android `minSdk 23`; iOS location permission
(`NSLocationWhenInUseUsageDescription`) — without it `user_wifi_network` comes
back empty; the quickstart below; and the mapping hazards.

````markdown
# scanmynet_sdk

Flutter plugin for the ScanMyNet network diagnostics SDK.

## Install

```yaml
dependencies:
  scanmynet_sdk: ^1.0.0
```

## Quickstart

```dart
final sdk = ();

sdk.events.listen((event) {
  switch (event) {
    case ScanProgressed(:final progress):
      print('${progress.percent}%');
    case ScanCompleted(:final result):
      print('Hosted report: ${result.reportUrl}');
      final report = result.report;
      if (report != null) {
        print('Down: ${report.customerInternetSpeed?.networkSpeedDown} Mbps');
        for (final alert in report.alerts ?? []) {
          switch (alert.type) {
            case AlertType.oldRouter: /* localise your own copy */
            case AlertType.unknown:   /* forward-compatible fallback */
            default: break;
          }
        }
      }
    case ScanFailed(:final error):
      print('Failed: ${error.message}');
    case ScanStarted():
    case ScanDataPersisted():
    case ScanCanceled():
  }
});

await sdk.configure(ScanConfig(apiKey: 'your-key'));
await sdk.startScan();
```

## Reading the report

`result.reportUrl` opens the hosted report and is always present.
`result.report` is the same data as structured Dart objects, for building your
own UI. It is null on backends predating the payload.

### Gotchas

| Shape | Where | Note |
|---|---|---|
| Single-entry map, not a struct | `customerInternetSpeed.connectionQuality` | `{"good": "green"}` — read the first entry |
| ...but this one **is** a struct | `connectionQualityColor` on devices and DNS results | `{quality, color}` |
| Different field names | `alerts` vs `actions` | `alert_*` vs `action_*`; not interchangeable |
| Null means "not detected" | `networkTopology.doubleNatDetected` | The key is absent, not false |
| `"Enabled"` / `"Disabled"` strings | `firewall`, `multicast`, `clientIsolation` | Not booleans |
| String, not int | `channelCongestion.index` | |

Branch on `alert.type` / `action.type`, never on `alertValue` / `actionValue` —
those are display strings, sometimes templated at runtime, and are not stable
identifiers. Unrecognised values resolve to `unknown` rather than throwing.
````

- [ ] **Step 6: Verify the package is publishable**

```bash
flutter pub publish --dry-run
```

Expected: no errors. A **license warning is expected and correct** — see Task 8.

- [ ] **Step 7: Confirm no credential remains**

```bash
grep -rn "<COMMITTED-KEY-REDACTED-ROTATE-ON-BACKEND>" . --exclude-dir=.git --exclude-dir=build || echo "clean"
```

Expected: `clean`.

- [ ] **Step 8: Staging checkpoint (do not commit)**

```bash
git add pubspec.yaml CHANGELOG.md README.md example/lib/app.dart example/README.md
```

Message: `docs: package metadata, integration docs, and remove committed API key`

---

### Task 8: Publication — OWNER-GATED

> ## 🔴 Do not execute without explicit approval
>
> Publication to pub.dev is irreversible. A version can be retracted within 7
> days but remains downloadable, and the package name is permanently claimed.
>
> **Two owner actions must complete first:**
>
> 1. **Rotate the API key** `<COMMITTED-KEY-REDACTED-ROTATE-ON-BACKEND>`. Task 7 removed
>    it from the working tree, but it remains in git history.
> 2. **Resolve the license.** `LICENSE` reads `TODO: Add your license here.`
>    Publishing publicly grants the world a redistribution right over the
>    package, which bundles three proprietary third-party binaries:
>    `ScanMyNet.xcframework`, `tools-1.1.aar` (creativeadvtech) and
>    `traceroute-1.0.0.aar` (synaptic-tools). Confirm vendor agreements permit
>    public redistribution, then add a real license.

- [ ] **Step 1: Confirm the gate is cleared**

Ask the owner directly. Both must be explicit:

- Has the API key been rotated?
- Is the license resolved, and do vendor agreements permit public redistribution
  of the bundled binaries?

Do not infer approval from silence or from a general "go ahead".

- [ ] **Step 2: Add the license file**

Replace `LICENSE` with the text the owner supplies. Do not choose one
unilaterally — the vendor binaries make this a legal decision, not a default.

- [ ] **Step 3: Final dry run**

```bash
flutter pub publish --dry-run
```

Expected: no errors, no license warning.

- [ ] **Step 4: Re-capture the golden fixture**

The payload tracks the FE contract. Run a live scan and diff the response
against `report_response_full.json` in both native repos. If it differs, update
the fixture in both and re-run all three test suites before publishing.

- [ ] **Step 5: Publish**

```bash
flutter pub publish
```

- [ ] **Step 6: Verify installability**

In a scratch directory:

```bash
flutter create /tmp/smn_check && cd /tmp/smn_check
flutter pub add scanmynet_sdk
flutter build apk --debug
```

Expected: resolves from pub.dev and builds — the acceptance criterion
"installable by Earthlink".

---

## Definition of Done

- [ ] All 15 sections modelled in Pigeon and generated to three languages
- [ ] Both native bridges map their DTOs onto Pigeon types
- [ ] `ScanCompleted` carries `report`, `reportId`, `customerId`
- [ ] Open enums resolve unknown values to `unknown` without throwing
- [ ] Schema version handshake fails loudly on mismatch
- [ ] Example app renders a live report on both platforms
- [ ] `flutter test` passes
- [ ] `flutter pub publish --dry-run` clean apart from the license gate
- [ ] No API key anywhere in the working tree
- [ ] Publication executed only after explicit owner approval
- [ ] All work staged, nothing committed, pending owner approval

## Notes for the implementer

**Append, never insert.** Pigeon encodes by position. Inserting a field into the
middle of an existing class silently shifts every later field's meaning across
the boundary — no exception, no error, just wrong data. Task 5's handshake
catches version skew but not a mid-class insertion within one version.

**The `SMN` prefix on framework types is load-bearing.** Pigeon's Swift
generator emits unprefixed names — verified against `SwiftOptions` (no prefix
option exists) and the current `Messages.g.swift`. Without the prefix on Plan 2's
framework models, the Pigeon types and the framework types would collide by name
inside this module and the mappers would silently extend the wrong type. If you
rename anything in Plan 2, keep the prefix.

**Int widths.** Pigeon's `int` is `Int64` in Swift and `Long` in Kotlin. Swift
models in Plan 2 use `Int`, so the iOS mapper needs `.map(Int64.init)` on every
integer. Kotlin DTOs in Plan 1 already use `Long`, so Android needs no
conversion. This asymmetry is deliberate — it keeps each native model idiomatic.

**`reportId` / `customerId` are Android-only as planned.** The iOS delegate
change in Plan 2 Task 7 threads only the payload. If Earthlink needs the
identifiers on iOS, extend that delegate signature — the Pigeon fields already
exist and will simply stay null on iOS until then.
