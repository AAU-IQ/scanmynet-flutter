# Report Payload — Android Native (Plan 1 of 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Widen the Android SDK's `POST /report/` response model so the full 15-section `report` object, `report_id` and `customer_id` are decoded and reachable by the Flutter plugin bridge.

**Architecture:** `ReportResponseDto` currently declares one field (`data: String`), so Gson silently discards the new keys. We add nullable response DTOs covering all 15 sections, decoded by the existing Retrofit/Gson stack. No behavioural change to the existing `data` contract, the Retrofit interface, or the scan pipeline. Every task is driven by a golden JSON fixture captured from a real response.

**Tech Stack:** Kotlin, Gson (via `retrofit2:converter-gson:3.0.0`), JUnit 4, Gradle `maven-publish`.

**Repo:** `C:\Users\abdal\BitBucket\scanmynet-android` (module: `tools`)

**Spec:** `scanmynet_sdk/docs/superpowers/specs/2026-07-20-report-payload-and-publish-design.md`

## Global Constraints

- **Every new field is nullable with a default.** No exceptions. Sections are built from whatever the SDK submitted; any key the scan did not supply comes back `null`, and `double_nat_detected` / `device_details` / `router_details` are absent entirely.
- **`data: String` stays exactly as-is** — first field, non-nullable, unchanged type. It is the shipped contract.
- **Response DTOs are new types.** Do not reuse or modify the existing request DTOs (`LocalDeviceDto`, `WifiNetworkDto`, `CongestionDto`, `DnsPingResultDto`, `PortDto`, `DnsLookupDto`, `ServerConnectivityDto`, `TracerouteDto`). They model the request and diverge — e.g. request `CongestionDto.index` is `Int?` but response `channel_congestion[].index` is a **String**.
- **Property names are raw snake_case**, matching the existing DTO convention. No `@SerializedName` annotations — the codebase relies on Gson's default field-name matching.
- **New response DTOs live in** `tools/src/main/java/com/creative/tools/rest/dto/response/`.
- **`alert_type` / `action_type` stay `String?`.** Never Kotlin enums — the backend adds members without an API version bump.
- **Do not commit.** The project owner has held all commits across all three repos. Each task ends with a staging checkpoint and the message to use once approval lands.
- Module version stays `1.0` until Task 7, which bumps it to `1.1`.

---

### Task 1: Golden fixture and top-level response widening

Establishes the fixture every later task asserts against, and proves the two contracts that must never break: a minimal response still decodes, and `data` is untouched.

**Files:**
- Create: `tools/src/test/resources/report_response_full.json`
- Create: `tools/src/test/resources/report_response_minimal.json`
- Modify: `tools/src/main/java/com/creative/tools/rest/dto/ReportResponseDto.kt`
- Create: `tools/src/test/java/com/creative/tools/rest/dto/ReportResponseDtoTest.kt`

**Interfaces:**
- Consumes: nothing.
- Produces: `ReportResponseDto(data: String, report_id: String?, customer_id: String?, report: ReportDto?)` and `ReportDto` — a placeholder in this task, populated field-by-field in Tasks 2-6. Test helper `loadFixture(name: String): String`.

- [ ] **Step 1: Create the minimal fixture**

This is the regression guard. A response carrying only `data` must always decode.

`tools/src/test/resources/report_response_minimal.json`:

```json
{
  "info": { "message": "success", "details": {} },
  "data": "https://scanmynet.earthlink.iq/#/view-report/?verification_token=abc123"
}
```

- [ ] **Step 2: Create the full fixture**

Covers every section. Values match the BE doc's examples so later tasks assert against known data.

`tools/src/test/resources/report_response_full.json`:

```json
{
  "info": { "message": "success", "details": {} },
  "data": "https://scanmynet.earthlink.iq/#/view-report/?verification_token=abc123",
  "report_id": "6f1b2c40-0000-0000-0000-0000a91e",
  "customer_id": "acme-key",
  "report": {
    "customer_details": {
      "key": "acme-key",
      "last_known_public_ip": "203.0.113.10",
      "last_known_public_ip_details": { "Country": "US", "Region": "Austin", "ISP": "Example ISP" }
    },
    "sdk_details": {
      "start": "2026-07-20T10:15:00", "duration": 42, "platform": "android",
      "app": "ScanMyNet", "route_this_sdk": "1.2.3",
      "user_public_up_address": "203.0.113.10",
      "gps_latitude": 30.2672, "gps_longitude": -97.7431
    },
    "router_usage_during_scan": { "network_usage_down": 1.4, "network_usage_up": 0.3 },
    "customer_internet_speed": {
      "network_speed_down": 87.4, "network_speed_up": 12.1,
      "current_negotiated_link_speed": 300.0,
      "maximum_link_supported_by_phone": "866 Mbps",
      "network_speed_up_segments": [11.8, 12.4],
      "network_speed_down_segments": [85.1, 89.7],
      "connection_quality": { "good": "green" }
    },
    "basic_connectivity": {
      "ip_assigned_via_dhcp": true,
      "server_connectivity": [{ "name": "google", "server_status": true }],
      "port_checks": [{ "port": 443, "port_type": "tcp", "description": "HTTPS", "port_status": true }],
      "dns_lookup": [{ "dns_ip": "8.8.8.8", "alias": "google", "reverse_dns": "dns.google" }],
      "summary": {
        "server_connectivity": { "status": "good connectivity", "color": "green" },
        "port_checks": { "status": "good connectivity", "color": "green" },
        "dns_lookup": ["google", "cloudflare"]
      },
      "servers": [], "udp": [], "tcp": [],
      "firewall": { "color": "green", "status": "", "value": "Disabled", "alerts": {} },
      "client_isolation": { "status": "possibly", "color": "green", "value": "Disabled" },
      "multicast": { "value": "Enabled", "color": "green", "status": "possibly" },
      "alerts": []
    },
    "local_connected_devices": [{
      "device_name": "living-room-tv", "device_ip": "192.168.1.42",
      "device_mac_address": "AA:BB:CC:DD:EE:FF", "manufacturer": "Samsung",
      "packets_dropped": 0.0, "num_packets_sent": 10,
      "ping_values": [12.1, 11.8], "is_subscriber_phone": false,
      "average_ping_time": 11.95,
      "connection_quality_color": { "quality": "good", "color": "green" },
      "is_subscriber_router": false,
      "device_details": { "mac": "AA:BB:CC:DD:EE:FF", "recognition": { "type": "TV", "model": "UN55" } }
    }],
    "customer_router_details": {
      "make": "Netgear", "model": "R7000", "encryption": "WPA2",
      "protocols": "802.11ac", "mesh": "no",
      "router_ip_address": "192.168.1.1", "router_mac_address": "AA:BB:CC:DD:EE:00",
      "manufacturer": "Netgear", "hostname": "router.lan",
      "model_description": "Nighthawk", "model_number": "R7000",
      "friendly_name": "Nighthawk R7000", "device_type": "InternetGatewayDevice",
      "router_details": { "mac": "AA:BB:CC:DD:EE:00", "recognition": { "model": "R7000" } }
    },
    "network_topology": {
      "router_ip_address": "192.168.1.1",
      "other_routers": ["192.168.1.1", "100.64.0.1", "203.0.113.1"],
      "other_routers_details": [{ "ip": "203.0.113.1", "owner": null }],
      "double_nat_detected": { "is_double_nat": true, "double_nat_hop": ["10.0.0.1"] }
    },
    "user_wifi_network": {
      "ssid": "MyNetwork", "ssid_ip": "192.168.1.42", "bssid": "AA:BB:CC:DD:EE:FF",
      "encryption": "WPA2", "frequency": 5.0, "wps_availability": false,
      "signal_strength": -52, "num_wifi_channels": 44,
      "channel_width": 80, "current_channel": 44
    },
    "network_congestion": {
      "user_connection": {
        "phone_wifi_frequency": 5.0, "num_phone_wifi_channel": 11,
        "num_networks_on_channel": 2, "phone_wifi_channel": 44
      },
      "environment": {
        "channel_congestion": [{ "index": "6", "num_networks": 4 }],
        "surrounding_wifi_networks": [{ "ssid": "Neighbour", "bssid": "BB:CC:DD:EE:FF:00", "is_subscriber_ssid": false }]
      }
    },
    "connection_quality": [{
      "dns_name": "google", "dns_ip": "8.8.8.8",
      "packets_dropped": 0.0, "num_packets_sent": 10,
      "ping_values": [14.2, 15.1], "is_subscriber_router": false,
      "jitter": 0.9, "average_ping_time": 14.65,
      "connection_quality_color": { "quality": "good", "color": "green" },
      "layer_ranking": 3
    }],
    "traceroute": [{
      "dns_destination_ip": "8.8.8.8",
      "hops": [{ "dns_ip": "192.168.1.1", "dns_name": "router.lan", "rtt_values": [1, 2, 1] }]
    }],
    "alerts": [{ "alert_type": "old_router", "alert_value": "Old Router Model Detected" }],
    "actions": [{ "action_type": "download_speed", "action_value": "Download speed" }],
    "incomplete_analysis": false
  }
}
```

- [ ] **Step 3: Write the failing test**

`tools/src/test/java/com/creative/tools/rest/dto/ReportResponseDtoTest.kt`:

```kotlin
package com.creative.tools.rest.dto

import com.google.gson.Gson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ReportResponseDtoTest {

    private val gson = Gson()

    @Test
    fun `minimal response still decodes and data is unchanged`() {
        val dto = gson.fromJson(loadFixture("report_response_minimal.json"), ReportResponseDto::class.java)

        assertEquals(
            "https://scanmynet.earthlink.iq/#/view-report/?verification_token=abc123",
            dto.data,
        )
        assertNull(dto.report_id)
        assertNull(dto.customer_id)
        assertNull(dto.report)
    }

    @Test
    fun `full response decodes top-level identifiers`() {
        val dto = gson.fromJson(loadFixture("report_response_full.json"), ReportResponseDto::class.java)

        assertEquals("6f1b2c40-0000-0000-0000-0000a91e", dto.report_id)
        assertEquals("acme-key", dto.customer_id)
    }

    companion object {
        fun loadFixture(name: String): String =
            ReportResponseDtoTest::class.java.classLoader!!
                .getResourceAsStream(name)!!
                .bufferedReader()
                .readText()
    }
}
```

- [ ] **Step 4: Run the test to verify it fails**

```bash
cd "C:/Users/abdal/BitBucket/scanmynet-android"
./gradlew :tools:testDebugUnitTest --tests "*ReportResponseDtoTest*"
```

Expected: FAIL — `Unresolved reference: report_id`.

- [ ] **Step 5: Widen `ReportResponseDto`**

Replace `tools/src/main/java/com/creative/tools/rest/dto/ReportResponseDto.kt`:

```kotlin
package com.creative.tools.rest.dto

import com.creative.tools.rest.dto.response.ReportDto

/**
 * Response of successful [ReportParamDto] submission.
 *
 * `data` is the shipped contract and is unchanged. The remaining fields were
 * added alongside it and are absent on older backends, so all are nullable.
 */
data class ReportResponseDto(
    /**
     * URL leading to the generated report online
     */
    val data: String,
    val report_id: String? = null,
    val customer_id: String? = null,
    val report: ReportDto? = null,
)
```

- [ ] **Step 6: Create the placeholder `ReportDto`**

Tasks 2-6 replace each `null` placeholder with a real type. Keeping the 15 keys present from the start means the root shape never changes shape mid-plan.

Create `tools/src/main/java/com/creative/tools/rest/dto/response/ReportDto.kt`:

```kotlin
package com.creative.tools.rest.dto.response

/**
 * The full report payload returned alongside the hosted report URL.
 *
 * All 15 section keys are always present in the JSON, but every one is
 * modelled nullable: the parent `report` object itself is optional, and an
 * absent parent makes every child absent.
 *
 * Section types are introduced incrementally (see plan Tasks 2-6). Sections
 * not yet typed are held as `Any?` and MUST be replaced before release.
 */
data class ReportDto(
    val customer_details: Any? = null,
    val sdk_details: Any? = null,
    val router_usage_during_scan: Any? = null,
    val customer_internet_speed: Any? = null,
    val basic_connectivity: Any? = null,
    val local_connected_devices: Any? = null,
    val customer_router_details: Any? = null,
    val network_topology: Any? = null,
    val user_wifi_network: Any? = null,
    val network_congestion: Any? = null,
    val connection_quality: Any? = null,
    val traceroute: Any? = null,
    val alerts: Any? = null,
    val actions: Any? = null,
    val incomplete_analysis: Boolean? = null,
)
```

- [ ] **Step 7: Run the test to verify it passes**

```bash
./gradlew :tools:testDebugUnitTest --tests "*ReportResponseDtoTest*"
```

Expected: PASS, 2 tests.

- [ ] **Step 8: Staging checkpoint (do not commit)**

```bash
git add tools/src/main/java/com/creative/tools/rest/dto/ReportResponseDto.kt \
        tools/src/main/java/com/creative/tools/rest/dto/response/ReportDto.kt \
        tools/src/test/java/com/creative/tools/rest/dto/ReportResponseDtoTest.kt \
        tools/src/test/resources/
```

Message to use once the owner approves commits:
`feat(dto): widen ReportResponseDto with report_id, customer_id and report`

---

### Task 2: Scalar sections — customer details, SDK details, usage, speed

The four sections with no nested collections. Establishes the `Map` handling for the two irregular shapes.

**Files:**
- Create: `tools/src/main/java/com/creative/tools/rest/dto/response/CustomerDetailsDto.kt`
- Create: `tools/src/main/java/com/creative/tools/rest/dto/response/SdkDetailsDto.kt`
- Create: `tools/src/main/java/com/creative/tools/rest/dto/response/RouterUsageDto.kt`
- Create: `tools/src/main/java/com/creative/tools/rest/dto/response/InternetSpeedDto.kt`
- Modify: `tools/src/main/java/com/creative/tools/rest/dto/response/ReportDto.kt`
- Create: `tools/src/test/java/com/creative/tools/rest/dto/response/ScalarSectionsTest.kt`

**Interfaces:**
- Consumes: `ReportDto` and `loadFixture` from Task 1.
- Produces: `CustomerDetailsDto`, `SdkDetailsDto`, `RouterUsageDto`, `InternetSpeedDto`. `InternetSpeedDto.connection_quality` is `Map<String, String>?` — a single-entry map keyed by the quality label.

- [ ] **Step 1: Write the failing test**

Note the two assertions that encode BE-doc hazards: capitalised geo keys, and quality-as-map rather than struct.

`tools/src/test/java/com/creative/tools/rest/dto/response/ScalarSectionsTest.kt`:

```kotlin
package com.creative.tools.rest.dto.response

import com.creative.tools.rest.dto.ReportResponseDto
import com.creative.tools.rest.dto.ReportResponseDtoTest.Companion.loadFixture
import com.google.gson.Gson
import org.junit.Assert.assertEquals
import org.junit.Test

class ScalarSectionsTest {

    private val report = Gson()
        .fromJson(loadFixture("report_response_full.json"), ReportResponseDto::class.java)
        .report!!

    @Test
    fun `customer details keeps capitalised geo keys verbatim`() {
        val details = report.customer_details!!
        assertEquals("acme-key", details.key)
        assertEquals("203.0.113.10", details.last_known_public_ip)
        assertEquals("US", details.last_known_public_ip_details!!["Country"])
        assertEquals("Austin", details.last_known_public_ip_details!!["Region"])
        assertEquals("Example ISP", details.last_known_public_ip_details!!["ISP"])
    }

    @Test
    fun `sdk details decodes duration and gps`() {
        val sdk = report.sdk_details!!
        assertEquals(42L, sdk.duration)
        assertEquals("android", sdk.platform)
        assertEquals(30.2672, sdk.gps_latitude!!, 0.0001)
    }

    @Test
    fun `router usage decodes both directions`() {
        val usage = report.router_usage_during_scan!!
        assertEquals(1.4, usage.network_usage_down!!, 0.001)
        assertEquals(0.3, usage.network_usage_up!!, 0.001)
    }

    @Test
    fun `connection quality is a single entry map keyed by label`() {
        val speed = report.customer_internet_speed!!
        assertEquals(87.4, speed.network_speed_down!!, 0.001)
        assertEquals(listOf(85.1, 89.7), speed.network_speed_down_segments)

        val quality = speed.connection_quality!!
        assertEquals(1, quality.size)
        assertEquals("good", quality.keys.first())
        assertEquals("green", quality.values.first())
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
./gradlew :tools:testDebugUnitTest --tests "*ScalarSectionsTest*"
```

Expected: FAIL — `.key` unresolved on `Any?`.

- [ ] **Step 3: Create the four DTOs**

`CustomerDetailsDto.kt`:

```kotlin
package com.creative.tools.rest.dto.response

/**
 * Subscriber key, public IP and resolved geo.
 *
 * `last_known_public_ip_details` keys are CAPITALISED (`Country`, `Region`,
 * `ISP`) and do not follow the snake_case of the rest of the payload. It is
 * held as a raw map so no key transformation is applied; individual keys may
 * be missing rather than null, and the map is `{}` when geo did not resolve.
 */
data class CustomerDetailsDto(
    val key: String? = null,
    val last_known_public_ip: String? = null,
    val last_known_public_ip_details: Map<String, String>? = null,
)
```

`SdkDetailsDto.kt`:

```kotlin
package com.creative.tools.rest.dto.response

/**
 * Scan run metadata. [duration] is in seconds.
 *
 * When either GPS field is null the backend emits a `missing_location` alert.
 */
data class SdkDetailsDto(
    val start: String? = null,
    val duration: Long? = null,
    val platform: String? = null,
    val app: String? = null,
    val route_this_sdk: String? = null,
    val user_public_up_address: String? = null,
    val gps_latitude: Double? = null,
    val gps_longitude: Double? = null,
)
```

`RouterUsageDto.kt`:

```kotlin
package com.creative.tools.rest.dto.response

/** Router usage counters observed during the scan, in Mbps. */
data class RouterUsageDto(
    val network_usage_down: Double? = null,
    val network_usage_up: Double? = null,
)
```

`InternetSpeedDto.kt`:

```kotlin
package com.creative.tools.rest.dto.response

/**
 * Speed test results.
 *
 * [connection_quality] is a SINGLE-ENTRY MAP keyed by the quality label —
 * `{"poor": "red"}`, `{"moderate": "yellow"}` or `{"good": "green"}` — and is
 * `{}` when [network_speed_down] is null. It is NOT a `{quality, color}`
 * struct; that shape is [QualityColorDto], used elsewhere in the payload.
 */
data class InternetSpeedDto(
    val network_speed_down: Double? = null,
    val network_speed_up: Double? = null,
    val current_negotiated_link_speed: Double? = null,
    val maximum_link_supported_by_phone: String? = null,
    val network_speed_up_segments: List<Double>? = null,
    val network_speed_down_segments: List<Double>? = null,
    val connection_quality: Map<String, String>? = null,
)
```

- [ ] **Step 4: Wire the four sections into `ReportDto`**

In `ReportDto.kt`, replace only these four lines:

```kotlin
    val customer_details: CustomerDetailsDto? = null,
    val sdk_details: SdkDetailsDto? = null,
    val router_usage_during_scan: RouterUsageDto? = null,
    val customer_internet_speed: InternetSpeedDto? = null,
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
./gradlew :tools:testDebugUnitTest --tests "*ScalarSectionsTest*"
```

Expected: PASS, 4 tests.

- [ ] **Step 6: Run the full module suite (regression guard)**

```bash
./gradlew :tools:testDebugUnitTest
```

Expected: PASS — including Task 1's minimal-response test.

- [ ] **Step 7: Staging checkpoint (do not commit)**

```bash
git add tools/src/main/java/com/creative/tools/rest/dto/response/ tools/src/test/java/com/creative/tools/rest/dto/response/
```

Message: `feat(dto): add customer details, sdk details, usage and speed sections`

---

### Task 3: Basic connectivity

The largest section — nine nested types, and three separate BE-doc hazards.

**Files:**
- Create: `tools/src/main/java/com/creative/tools/rest/dto/response/BasicConnectivityDto.kt` (all nine types in one file — they are only used together)
- Modify: `tools/src/main/java/com/creative/tools/rest/dto/response/ReportDto.kt`
- Create: `tools/src/test/java/com/creative/tools/rest/dto/response/BasicConnectivityTest.kt`

**Interfaces:**
- Consumes: `ReportDto`, `loadFixture`.
- Produces: `BasicConnectivityDto`, `ServerConnectivityResultDto`, `PortCheckDto`, `DnsLookupResultDto`, `ConnectivitySummaryDto`, `StatusColorDto`, `ToggleStateDto`, `AlertDto`.
  `AlertDto(alert_type: String?, alert_value: String?)` is reused by Task 6's top-level `alerts`.

- [ ] **Step 1: Write the failing test**

```kotlin
package com.creative.tools.rest.dto.response

import com.creative.tools.rest.dto.ReportResponseDto
import com.creative.tools.rest.dto.ReportResponseDtoTest.Companion.loadFixture
import com.google.gson.Gson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BasicConnectivityTest {

    private val connectivity = Gson()
        .fromJson(loadFixture("report_response_full.json"), ReportResponseDto::class.java)
        .report!!.basic_connectivity!!

    @Test
    fun `decodes lists and dhcp flag`() {
        assertEquals(true, connectivity.ip_assigned_via_dhcp)
        assertEquals("google", connectivity.server_connectivity!!.first().name)
        assertEquals(true, connectivity.server_connectivity!!.first().server_status)
        assertEquals(443L, connectivity.port_checks!!.first().port)
        assertEquals("tcp", connectivity.port_checks!!.first().port_type)
        assertEquals("dns.google", connectivity.dns_lookup!!.first().reverse_dns)
    }

    @Test
    fun `summary dns lookup is a string list while siblings are objects`() {
        val summary = connectivity.summary!!
        assertEquals("green", summary.server_connectivity!!.color)
        assertEquals("good connectivity", summary.port_checks!!.status)
        assertEquals(listOf("google", "cloudflare"), summary.dns_lookup)
    }

    @Test
    fun `toggle values are Enabled Disabled strings not booleans`() {
        assertEquals("Disabled", connectivity.firewall!!.value)
        assertEquals("Disabled", connectivity.client_isolation!!.value)
        assertEquals("Enabled", connectivity.multicast!!.value)
    }

    @Test
    fun `blocked server and port lists are empty when nothing blocked`() {
        assertTrue(connectivity.servers!!.isEmpty())
        assertTrue(connectivity.udp!!.isEmpty())
        assertTrue(connectivity.tcp!!.isEmpty())
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
./gradlew :tools:testDebugUnitTest --tests "*BasicConnectivityTest*"
```

Expected: FAIL — unresolved references on `Any?`.

- [ ] **Step 3: Create `BasicConnectivityDto.kt`**

```kotlin
package com.creative.tools.rest.dto.response

/**
 * Firewall, port, DNS and multicast checks.
 *
 * [servers], [udp] and [tcp] list the *blocked* server names and port numbers.
 *
 * [alerts] is ALWAYS an empty array — real alerts are promoted to the
 * top-level `report.alerts`. It is modelled only so the field is accounted
 * for; do not read it.
 */
data class BasicConnectivityDto(
    val ip_assigned_via_dhcp: Boolean? = null,
    val server_connectivity: List<ServerConnectivityResultDto>? = null,
    val port_checks: List<PortCheckDto>? = null,
    val dns_lookup: List<DnsLookupResultDto>? = null,
    val summary: ConnectivitySummaryDto? = null,
    val servers: List<String>? = null,
    val udp: List<Long>? = null,
    val tcp: List<Long>? = null,
    val firewall: ToggleStateDto? = null,
    val client_isolation: ToggleStateDto? = null,
    val multicast: ToggleStateDto? = null,
    val alerts: List<AlertDto>? = null,
)

/** One reachability probe result. */
data class ServerConnectivityResultDto(
    val name: String? = null,
    val server_status: Boolean? = null,
)

/** One port probe result. */
data class PortCheckDto(
    val port: Long? = null,
    val port_type: String? = null,
    val description: String? = null,
    val port_status: Boolean? = null,
)

/** One DNS resolution result. */
data class DnsLookupResultDto(
    val dns_ip: String? = null,
    val alias: String? = null,
    val reverse_dns: String? = null,
)

/**
 * Roll-up of the three checks above.
 *
 * The three entries do NOT share a type: [server_connectivity] and
 * [port_checks] are `{status, color}` objects, while [dns_lookup] is a plain
 * array of alias strings.
 */
data class ConnectivitySummaryDto(
    val server_connectivity: StatusColorDto? = null,
    val port_checks: StatusColorDto? = null,
    val dns_lookup: List<String>? = null,
)

/** A `{status, color}` roll-up pair. */
data class StatusColorDto(
    val status: String? = null,
    val color: String? = null,
)

/**
 * Firewall / client-isolation / multicast state.
 *
 * [value] is the STRING `"Enabled"` or `"Disabled"`, never a boolean. The
 * whole object is `{}` when the state could not be determined.
 *
 * [alerts] is an ALERT OBJECT or `{}` — not an array. `client_isolation` and
 * `multicast` carry the key only when an alert applies.
 */
data class ToggleStateDto(
    val value: String? = null,
    val color: String? = null,
    val status: String? = null,
    val alerts: AlertDto? = null,
)

/**
 * A report alert.
 *
 * [alert_type] is deliberately a String, not an enum — the backend adds
 * members without an API version bump. Branch on [alert_type]; never match on
 * [alert_value], which is a display-ready English string, sometimes templated
 * at runtime.
 */
data class AlertDto(
    val alert_type: String? = null,
    val alert_value: String? = null,
)
```

- [ ] **Step 4: Wire into `ReportDto`**

Replace one line in `ReportDto.kt`:

```kotlin
    val basic_connectivity: BasicConnectivityDto? = null,
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
./gradlew :tools:testDebugUnitTest --tests "*BasicConnectivityTest*"
```

Expected: PASS, 4 tests.

- [ ] **Step 6: Staging checkpoint (do not commit)**

```bash
git add tools/src/main/java/com/creative/tools/rest/dto/response/BasicConnectivityDto.kt \
        tools/src/test/java/com/creative/tools/rest/dto/response/BasicConnectivityTest.kt \
        tools/src/main/java/com/creative/tools/rest/dto/response/ReportDto.kt
```

Message: `feat(dto): add basic connectivity section`

---

### Task 4: Connected devices and router details

**Files:**
- Create: `tools/src/main/java/com/creative/tools/rest/dto/response/LocalConnectedDeviceDto.kt`
- Create: `tools/src/main/java/com/creative/tools/rest/dto/response/CustomerRouterDetailsDto.kt`
- Modify: `tools/src/main/java/com/creative/tools/rest/dto/response/ReportDto.kt`
- Create: `tools/src/test/java/com/creative/tools/rest/dto/response/DevicesAndRouterTest.kt`

**Interfaces:**
- Consumes: `ReportDto`, `loadFixture`.
- Produces: `LocalConnectedDeviceDto`, `QualityColorDto`, `DeviceRecognitionDto`, `CustomerRouterDetailsDto`. `QualityColorDto(quality, color)` is reused by Task 5's `connection_quality`.

- [ ] **Step 1: Write the failing test**

```kotlin
package com.creative.tools.rest.dto.response

import com.creative.tools.rest.dto.ReportResponseDto
import com.creative.tools.rest.dto.ReportResponseDtoTest.Companion.loadFixture
import com.google.gson.Gson
import org.junit.Assert.assertEquals
import org.junit.Test

class DevicesAndRouterTest {

    private val report = Gson()
        .fromJson(loadFixture("report_response_full.json"), ReportResponseDto::class.java)
        .report!!

    @Test
    fun `device decodes ping stats and quality struct`() {
        val device = report.local_connected_devices!!.first()
        assertEquals("living-room-tv", device.device_name)
        assertEquals("AA:BB:CC:DD:EE:FF", device.device_mac_address)
        assertEquals(11.95, device.average_ping_time!!, 0.001)
        assertEquals(listOf(12.1, 11.8), device.ping_values)
        assertEquals(false, device.is_subscriber_router)

        // Distinct from InternetSpeedDto.connection_quality: this IS a struct.
        assertEquals("good", device.connection_quality_color!!.quality)
        assertEquals("green", device.connection_quality_color!!.color)
    }

    @Test
    fun `device recognition is an open map`() {
        val recognition = report.local_connected_devices!!.first().device_details!!.recognition!!
        assertEquals("TV", recognition["type"])
        assertEquals("UN55", recognition["model"])
    }

    @Test
    fun `router details decode`() {
        val router = report.customer_router_details!!
        assertEquals("Netgear", router.make)
        assertEquals("R7000", router.model)
        assertEquals("192.168.1.1", router.router_ip_address)
        assertEquals("R7000", router.router_details!!.recognition!!["model"])
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
./gradlew :tools:testDebugUnitTest --tests "*DevicesAndRouterTest*"
```

Expected: FAIL — unresolved references.

- [ ] **Step 3: Create `LocalConnectedDeviceDto.kt`**

```kotlin
package com.creative.tools.rest.dto.response

/**
 * A device discovered on the LAN.
 *
 * [average_ping_time] is `0` (not null) when [ping_values] is empty.
 * [device_details] is ABSENT — not null — when device recognition did not run.
 *
 * This is a RESPONSE type and is deliberately separate from the request-side
 * `LocalDeviceDto`, which lacks [average_ping_time],
 * [connection_quality_color], [device_details] and [is_subscriber_router].
 */
data class LocalConnectedDeviceDto(
    val device_name: String? = null,
    val device_ip: String? = null,
    val device_mac_address: String? = null,
    val manufacturer: String? = null,
    val packets_dropped: Double? = null,
    val num_packets_sent: Long? = null,
    val ping_values: List<Double>? = null,
    val is_subscriber_phone: Boolean? = null,
    val average_ping_time: Double? = null,
    val connection_quality_color: QualityColorDto? = null,
    val is_subscriber_router: Boolean? = null,
    val device_details: DeviceRecognitionDto? = null,
)

/**
 * A genuine `{quality, color}` struct.
 *
 * Not to be confused with `InternetSpeedDto.connection_quality`, which is a
 * single-entry map keyed by the label.
 */
data class QualityColorDto(
    val quality: String? = null,
    val color: String? = null,
)

/**
 * Third-party (Fing) device recognition.
 *
 * [recognition] is an open payload whose contents are not contractual — it is
 * held as a raw map and decoded defensively by consumers.
 */
data class DeviceRecognitionDto(
    val mac: String? = null,
    val recognition: Map<String, Any?>? = null,
)
```

- [ ] **Step 4: Create `CustomerRouterDetailsDto.kt`**

```kotlin
package com.creative.tools.rest.dto.response

/**
 * Router make, model and identity.
 *
 * [router_details] is present only when [router_mac_address] is non-null.
 *
 * The fields `age`, `price_at_launch`, `router_firmware` and `type` were
 * REMOVED from the contract — do not add them back.
 */
data class CustomerRouterDetailsDto(
    val make: String? = null,
    val model: String? = null,
    val encryption: String? = null,
    val protocols: String? = null,
    val mesh: String? = null,
    val router_ip_address: String? = null,
    val router_mac_address: String? = null,
    val manufacturer: String? = null,
    val hostname: String? = null,
    val model_description: String? = null,
    val model_number: String? = null,
    val friendly_name: String? = null,
    val device_type: String? = null,
    val router_details: DeviceRecognitionDto? = null,
)
```

- [ ] **Step 5: Wire into `ReportDto`**

```kotlin
    val local_connected_devices: List<LocalConnectedDeviceDto>? = null,
    val customer_router_details: CustomerRouterDetailsDto? = null,
```

- [ ] **Step 6: Run the test to verify it passes**

```bash
./gradlew :tools:testDebugUnitTest --tests "*DevicesAndRouterTest*"
```

Expected: PASS, 3 tests.

- [ ] **Step 7: Staging checkpoint (do not commit)**

```bash
git add tools/src/main/java/com/creative/tools/rest/dto/response/ tools/src/test/java/com/creative/tools/rest/dto/response/
```

Message: `feat(dto): add connected devices and router details sections`

---

### Task 5: Topology, wifi network and congestion

**Files:**
- Create: `tools/src/main/java/com/creative/tools/rest/dto/response/NetworkTopologyDto.kt`
- Create: `tools/src/main/java/com/creative/tools/rest/dto/response/WifiNetworkResultDto.kt`
- Create: `tools/src/main/java/com/creative/tools/rest/dto/response/NetworkCongestionDto.kt`
- Modify: `tools/src/main/java/com/creative/tools/rest/dto/response/ReportDto.kt`
- Create: `tools/src/test/java/com/creative/tools/rest/dto/response/TopologyWifiCongestionTest.kt`

**Interfaces:**
- Consumes: `ReportDto`, `loadFixture`.
- Produces: `NetworkTopologyDto`, `OtherRouterDetailDto`, `DoubleNatDto`, `WifiNetworkResultDto`, `NetworkCongestionDto`, `UserConnectionDto`, `CongestionEnvironmentDto`, `ChannelCongestionDto`.

- [ ] **Step 1: Write the failing test**

The `index` assertion is the one that catches accidental reuse of the request-side `CongestionDto`.

```kotlin
package com.creative.tools.rest.dto.response

import com.creative.tools.rest.dto.ReportResponseDto
import com.creative.tools.rest.dto.ReportResponseDtoTest.Companion.loadFixture
import com.google.gson.Gson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TopologyWifiCongestionTest {

    private val report = Gson()
        .fromJson(loadFixture("report_response_full.json"), ReportResponseDto::class.java)
        .report!!

    @Test
    fun `topology decodes routers and double nat`() {
        val topology = report.network_topology!!
        assertEquals("192.168.1.1", topology.router_ip_address)
        assertEquals(3, topology.other_routers!!.size)
        assertEquals(true, topology.double_nat_detected!!.is_double_nat)
        assertEquals(listOf("10.0.0.1"), topology.double_nat_detected!!.double_nat_hop)
        // owner is null until the ASN database is provisioned server-side
        assertNull(topology.other_routers_details!!.first().owner)
    }

    @Test
    fun `absent double nat decodes as null rather than failing`() {
        val json = """{"data":"u","report":{"network_topology":{"router_ip_address":"192.168.1.1"}}}"""
        val dto = Gson().fromJson(json, ReportResponseDto::class.java)
        assertNull(dto.report!!.network_topology!!.double_nat_detected)
    }

    @Test
    fun `user wifi network decodes with GHz frequency and dBm signal`() {
        val wifi = report.user_wifi_network!!
        assertEquals("MyNetwork", wifi.ssid)
        assertEquals(5.0, wifi.frequency!!, 0.001)
        assertEquals(-52L, wifi.signal_strength)
        assertEquals(44L, wifi.current_channel)
    }

    @Test
    fun `channel congestion index is a string not an int`() {
        val congestion = report.network_congestion!!
        assertEquals(44L, congestion.user_connection!!.phone_wifi_channel)
        assertEquals("6", congestion.environment!!.channel_congestion!!.first().index)
        assertEquals(4L, congestion.environment!!.channel_congestion!!.first().num_networks)
        assertEquals(
            "Neighbour",
            congestion.environment!!.surrounding_wifi_networks!!.first().ssid,
        )
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
./gradlew :tools:testDebugUnitTest --tests "*TopologyWifiCongestionTest*"
```

Expected: FAIL — unresolved references.

- [ ] **Step 3: Create `NetworkTopologyDto.kt`**

```kotlin
package com.creative.tools.rest.dto.response

/**
 * Hop list and double-NAT detection.
 *
 * [other_routers] is de-duplicated and ordered by first appearance across
 * traceroute hops.
 */
data class NetworkTopologyDto(
    val router_ip_address: String? = null,
    val other_routers: List<String>? = null,
    val other_routers_details: List<OtherRouterDetailDto>? = null,
    /**
     * ABSENT ENTIRELY when no double NAT is found — not null, and not
     * `{is_double_nat: false}`. Treat null as "no double NAT".
     */
    val double_nat_detected: DoubleNatDto? = null,
)

/** [owner] is null until the ASN database is provisioned server-side. */
data class OtherRouterDetailDto(
    val ip: String? = null,
    val owner: String? = null,
)

data class DoubleNatDto(
    val is_double_nat: Boolean? = null,
    val double_nat_hop: List<String>? = null,
)
```

- [ ] **Step 4: Create `WifiNetworkResultDto.kt`**

```kotlin
package com.creative.tools.rest.dto.response

/**
 * A WiFi network — the subscriber's own (`user_wifi_network`, `{}` when it
 * could not be identified, typically location permission denied) or a
 * surrounding one, which additionally carries [is_subscriber_ssid].
 *
 * [frequency] is in GHz (e.g. `2.4`, `5.0`). [signal_strength] is dBm and
 * therefore negative.
 *
 * Separate from the request-side `WifiNetworkDto`, which has no
 * [current_channel].
 */
data class WifiNetworkResultDto(
    val ssid: String? = null,
    val ssid_ip: String? = null,
    val bssid: String? = null,
    val encryption: String? = null,
    val frequency: Double? = null,
    val wps_availability: Boolean? = null,
    val signal_strength: Long? = null,
    val num_wifi_channels: Long? = null,
    val channel_width: Long? = null,
    val current_channel: Long? = null,
    val is_subscriber_ssid: Boolean? = null,
)
```

- [ ] **Step 5: Create `NetworkCongestionDto.kt`**

```kotlin
package com.creative.tools.rest.dto.response

/** Channel congestion and neighbouring networks. `{}` when no SSIDs submitted. */
data class NetworkCongestionDto(
    val user_connection: UserConnectionDto? = null,
    val environment: CongestionEnvironmentDto? = null,
)

/**
 * The subscriber's own connection.
 *
 * [num_phone_wifi_channel] is the COUNT of congestion entries, not a channel
 * number — the actual channel is [phone_wifi_channel].
 */
data class UserConnectionDto(
    val phone_wifi_frequency: Double? = null,
    val num_phone_wifi_channel: Long? = null,
    val num_networks_on_channel: Long? = null,
    val phone_wifi_channel: Long? = null,
)

/** [surrounding_wifi_networks] excludes the subscriber's own SSID. */
data class CongestionEnvironmentDto(
    val channel_congestion: List<ChannelCongestionDto>? = null,
    val surrounding_wifi_networks: List<WifiNetworkResultDto>? = null,
)

/**
 * Congestion on one channel.
 *
 * [index] is a STRING, not an int. The request-side `CongestionDto.index` is
 * `Int?` — these types are not interchangeable.
 */
data class ChannelCongestionDto(
    val index: String? = null,
    val num_networks: Long? = null,
)
```

- [ ] **Step 6: Wire into `ReportDto`**

```kotlin
    val network_topology: NetworkTopologyDto? = null,
    val user_wifi_network: WifiNetworkResultDto? = null,
    val network_congestion: NetworkCongestionDto? = null,
```

- [ ] **Step 7: Run the test to verify it passes**

```bash
./gradlew :tools:testDebugUnitTest --tests "*TopologyWifiCongestionTest*"
```

Expected: PASS, 4 tests.

- [ ] **Step 8: Staging checkpoint (do not commit)**

```bash
git add tools/src/main/java/com/creative/tools/rest/dto/response/ tools/src/test/java/com/creative/tools/rest/dto/response/
```

Message: `feat(dto): add topology, wifi network and congestion sections`

---

### Task 6: Connection quality, traceroute, alerts and actions

Completes `ReportDto`. After this task no `Any?` placeholders remain.

**Files:**
- Create: `tools/src/main/java/com/creative/tools/rest/dto/response/DnsQualityDto.kt`
- Create: `tools/src/main/java/com/creative/tools/rest/dto/response/TracerouteResultDto.kt`
- Create: `tools/src/main/java/com/creative/tools/rest/dto/response/ActionDto.kt`
- Modify: `tools/src/main/java/com/creative/tools/rest/dto/response/ReportDto.kt`
- Create: `tools/src/test/java/com/creative/tools/rest/dto/response/QualityTracerouteAlertsTest.kt`

**Interfaces:**
- Consumes: `ReportDto`, `QualityColorDto` (Task 4), `AlertDto` (Task 3), `loadFixture`.
- Produces: `DnsQualityDto`, `TracerouteResultDto`, `TracerouteHopDto`, `ActionDto`. Completed `ReportDto` with all 15 sections typed.

- [ ] **Step 1: Write the failing test**

```kotlin
package com.creative.tools.rest.dto.response

import com.creative.tools.rest.dto.ReportResponseDto
import com.creative.tools.rest.dto.ReportResponseDtoTest.Companion.loadFixture
import com.google.gson.Gson
import org.junit.Assert.assertEquals
import org.junit.Test

class QualityTracerouteAlertsTest {

    private val report = Gson()
        .fromJson(loadFixture("report_response_full.json"), ReportResponseDto::class.java)
        .report!!

    @Test
    fun `dns quality decodes jitter and layer ranking`() {
        val quality = report.connection_quality!!.first()
        assertEquals("google", quality.dns_name)
        assertEquals(0.9, quality.jitter!!, 0.001)
        assertEquals(14.65, quality.average_ping_time!!, 0.001)
        assertEquals(3L, quality.layer_ranking)
        assertEquals("good", quality.connection_quality_color!!.quality)
    }

    @Test
    fun `traceroute decodes hops with integer rtts`() {
        val trace = report.traceroute!!.first()
        assertEquals("8.8.8.8", trace.dns_destination_ip)
        assertEquals("router.lan", trace.hops!!.first().dns_name)
        assertEquals(listOf(1L, 2L, 1L), trace.hops!!.first().rtt_values)
    }

    @Test
    fun `alerts and actions use different field names`() {
        assertEquals("old_router", report.alerts!!.first().alert_type)
        assertEquals("Old Router Model Detected", report.alerts!!.first().alert_value)
        assertEquals("download_speed", report.actions!!.first().action_type)
        assertEquals("Download speed", report.actions!!.first().action_value)
    }

    @Test
    fun `unknown alert type decodes as a plain string`() {
        val json = """{"data":"u","report":{"alerts":[{"alert_type":"brand_new_type","alert_value":"x"}]}}"""
        val dto = Gson().fromJson(json, ReportResponseDto::class.java)
        assertEquals("brand_new_type", dto.report!!.alerts!!.first().alert_type)
    }

    @Test
    fun `incomplete analysis decodes`() {
        assertEquals(false, report.incomplete_analysis)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
./gradlew :tools:testDebugUnitTest --tests "*QualityTracerouteAlertsTest*"
```

Expected: FAIL — unresolved references.

- [ ] **Step 3: Create `DnsQualityDto.kt`**

```kotlin
package com.creative.tools.rest.dto.response

/**
 * Per-DNS ping result.
 *
 * [layer_ranking] is `1` (local), `2` (unknown/default) or `3` (external).
 * The entry with [is_subscriber_router] true is the subscriber's own router,
 * useful for separating in-home from outside-home quality.
 *
 * Separate from the request-side `DnsPingResultDto`, which lacks [jitter],
 * [average_ping_time], [layer_ranking] and [connection_quality_color].
 */
data class DnsQualityDto(
    val dns_name: String? = null,
    val dns_ip: String? = null,
    val packets_dropped: Double? = null,
    val num_packets_sent: Long? = null,
    val ping_values: List<Double>? = null,
    val is_subscriber_router: Boolean? = null,
    val jitter: Double? = null,
    val average_ping_time: Double? = null,
    val connection_quality_color: QualityColorDto? = null,
    val layer_ranking: Long? = null,
)
```

- [ ] **Step 4: Create `TracerouteResultDto.kt`**

```kotlin
package com.creative.tools.rest.dto.response

/** Raw traceroute, passed through unmodified from the request. */
data class TracerouteResultDto(
    val dns_destination_ip: String? = null,
    val hops: List<TracerouteHopDto>? = null,
)

/** [rtt_values] are integers in milliseconds. [dns_name] is nullable. */
data class TracerouteHopDto(
    val dns_ip: String? = null,
    val dns_name: String? = null,
    val rtt_values: List<Long>? = null,
)
```

- [ ] **Step 5: Create `ActionDto.kt`**

```kotlin
package com.creative.tools.rest.dto.response

/**
 * A report recommendation.
 *
 * NOTE the field names differ from [AlertDto]: actions use `action_*`, alerts
 * use `alert_*`. They are not `type` / `message`, and the two are not
 * interchangeable.
 *
 * [action_type] is deliberately a String, not an enum — members are added
 * without an API version bump. Branch on [action_type]; never match on
 * [action_value], which is a display string, sometimes templated at runtime.
 */
data class ActionDto(
    val action_type: String? = null,
    val action_value: String? = null,
)
```

- [ ] **Step 6: Complete `ReportDto`**

Replace the whole file — no `Any?` may remain:

```kotlin
package com.creative.tools.rest.dto.response

/**
 * The full report payload returned alongside the hosted report URL.
 *
 * All 15 section keys are always present in the JSON, but every one is
 * modelled nullable: the parent `report` object itself is optional, and an
 * absent parent makes every child absent.
 *
 * This mirrors the frontend contract and evolves with it — it is NOT a stable
 * versioned schema. Consumers must decode leniently and tolerate new keys.
 */
data class ReportDto(
    val customer_details: CustomerDetailsDto? = null,
    val sdk_details: SdkDetailsDto? = null,
    val router_usage_during_scan: RouterUsageDto? = null,
    val customer_internet_speed: InternetSpeedDto? = null,
    val basic_connectivity: BasicConnectivityDto? = null,
    val local_connected_devices: List<LocalConnectedDeviceDto>? = null,
    val customer_router_details: CustomerRouterDetailsDto? = null,
    val network_topology: NetworkTopologyDto? = null,
    val user_wifi_network: WifiNetworkResultDto? = null,
    val network_congestion: NetworkCongestionDto? = null,
    val connection_quality: List<DnsQualityDto>? = null,
    val traceroute: List<TracerouteResultDto>? = null,
    val alerts: List<AlertDto>? = null,
    val actions: List<ActionDto>? = null,
    val incomplete_analysis: Boolean? = null,
)
```

- [ ] **Step 7: Run the test to verify it passes**

```bash
./gradlew :tools:testDebugUnitTest --tests "*QualityTracerouteAlertsTest*"
```

Expected: PASS, 5 tests.

- [ ] **Step 8: Run the full module suite**

```bash
./gradlew :tools:testDebugUnitTest
```

Expected: PASS — all sections plus the Task 1 minimal-response regression guard.

- [ ] **Step 9: Verify no placeholders remain**

```bash
grep -n "Any?" tools/src/main/java/com/creative/tools/rest/dto/response/ReportDto.kt
```

Expected: no output. (`DeviceRecognitionDto.recognition` is `Map<String, Any?>` by design and lives in a different file.)

- [ ] **Step 10: Staging checkpoint (do not commit)**

```bash
git add tools/src/main/java/com/creative/tools/rest/dto/response/ tools/src/test/java/com/creative/tools/rest/dto/response/
```

Message: `feat(dto): add quality, traceroute, alerts and actions sections`

---

### Task 7: Build and publish AAR 1.1 into the Flutter plugin

Produces the artifact Plan 3 consumes. No source changes beyond the version bump.

**Files:**
- Modify: `tools/build.gradle:89`
- Modify (generated output): `scanmynet_sdk/android/local-maven-repo/org/bitbucket/creativeadvtech/tools/1.1/`
- Modify: `scanmynet_sdk/android/build.gradle.kts` (dependency version)

**Interfaces:**
- Consumes: completed `ReportDto` from Task 6.
- Produces: `org.bitbucket.creativeadvtech:tools:1.1` in the plugin's local maven repo.

> **Publishing works via maven-local, not a direct publish.** `tools/build.gradle`
> declares a `publications` block but **no `publishing { repositories { } }`
> block**, so there is no repository for `:tools:publish` to target. The artifact
> reaches the plugin in two hops: publish to `~/.m2`, then copy into the plugin's
> `local-maven-repo/`. This is how `1.0` was produced — hence `mavenLocal()` in
> `settings.gradle` and the Maven-generated checksums already sitting alongside
> `tools-1.0.aar`.

- [ ] **Step 1: Bump the module version**

In `tools/build.gradle`, line 89:

```groovy
                version = '1.1'
```

And line 24, so the compiled-in version string stays in step:

```groovy
        buildConfigField 'String', 'VERSION_NAME', "\"v1.1.0\""
```

- [ ] **Step 2: Build and publish to maven local**

```bash
cd "C:/Users/abdal/BitBucket/scanmynet-android"
./gradlew :tools:assembleRelease :tools:publishToMavenLocal
```

Expected: BUILD SUCCESSFUL.

Note `android.publishing.singleVariant('release') { withSourcesJar() }` is
configured, so a `-sources.jar` is produced alongside the AAR.

- [ ] **Step 3: Verify the artifact landed in maven local**

```bash
ls ~/.m2/repository/org/bitbucket/creativeadvtech/tools/1.1/
```

Expected: `tools-1.1.aar`, `tools-1.1-sources.jar`, `tools-1.1.pom`, plus checksums.

If this directory is empty, the publish silently no-opped — re-check the version bump in Step 1 landed in the `publications` block, not just `buildConfigField`.

- [ ] **Step 4: Copy into the plugin's local maven repo**

```bash
SRC=~/.m2/repository/org/bitbucket/creativeadvtech/tools/1.1
DEST="C:/Users/abdal/BitBucket/scanmynet_sdk/android/local-maven-repo/org/bitbucket/creativeadvtech/tools/1.1"
mkdir -p "$DEST"
cp "$SRC"/* "$DEST"/
ls "$DEST"
```

Expected: the AAR, sources jar, POM and checksums, mirroring the `1.0/` directory's layout.

Regenerate checksums only if the copy is missing them:

```bash
cd "$DEST"
for f in tools-1.1.aar tools-1.1.pom; do
  md5sum    "$f" | cut -d' ' -f1 > "$f.md5"
  sha1sum   "$f" | cut -d' ' -f1 > "$f.sha1"
  sha256sum "$f" | cut -d' ' -f1 > "$f.sha256"
  sha512sum "$f" | cut -d' ' -f1 > "$f.sha512"
done
```

Note `.gitignore` in `scanmynet_sdk` contains `*.jar`, so `tools-1.1-sources.jar` will not be tracked — matching `1.0`, where only the `.aar` is in git. This is expected, not a problem to fix.

- [ ] **Step 5: Point the plugin at 1.1**

In `scanmynet_sdk/android/build.gradle.kts:83`:

```kotlin
    implementation("org.bitbucket.creativeadvtech:tools:1.1")
```

- [ ] **Step 6: Verify the plugin still builds**

```bash
cd "C:/Users/abdal/BitBucket/scanmynet_sdk/example"
flutter build apk --debug
```

Expected: BUILD SUCCESSFUL. The bridge does not read the new fields yet — that is Plan 3 — so this only proves the dependency resolves and nothing broke.

- [ ] **Step 7: Staging checkpoint (do not commit)**

In `scanmynet-android`:

```bash
git add tools/build.gradle
```

Message: `chore(tools): bump to 1.1 for report response payload`

In `scanmynet_sdk`:

```bash
git add android/local-maven-repo/org/bitbucket/creativeadvtech/tools/1.1/ android/build.gradle.kts
```

Message: `chore(android): consume tools 1.1 with report response payload`

**Do not delete the 1.0 artifact** until Plan 3 is verified end-to-end — it is the rollback path.

---

## Definition of Done

- [ ] All 15 sections typed; no `Any?` in `ReportDto`
- [ ] `./gradlew :tools:testDebugUnitTest` passes
- [ ] Minimal `{"data": "..."}` response still decodes (Task 1 regression guard)
- [ ] `tools-1.1.aar` present in the plugin's local maven repo
- [ ] `flutter build apk --debug` succeeds in `scanmynet_sdk/example`
- [ ] All work staged, nothing committed, pending owner approval

## Notes for the implementer

**Why the request DTOs are not reused.** `tools/src/main/java/com/creative/tools/rest/dto/` already contains `LocalDeviceDto`, `WifiNetworkDto`, `CongestionDto` and friends. They look like the response shapes but are not. `CongestionDto.index` is `Int?` while the response's is a `String`; `LocalDeviceDto` is missing four response fields. Reusing them produces silently wrong data rather than a compile error, which is why response types live in their own `response/` package.

**Why every field is nullable.** The BE doc states almost every field is nullable and three keys are absent entirely. Gson tolerates missing keys by leaving the property at its default, so a non-null Kotlin type with no default would yield a null at runtime in violation of its own declared type — a latent NPE. Defaults everywhere avoid that.

**R8 / ProGuard is already handled — do not add keep rules.** The release build
sets `minifyEnabled true`, and Gson resolves fields reflectively by name, so
obfuscation would silently break decoding. This was checked:
`tools/proguard-rules.pro` already contains
`-keep class com.creative.tools.rest.dto.** { <fields>; }`, and the `**` wildcard
covers the new `dto.response` subpackage. `-keepattributes Signature` is also
present, which preserves the generic type information that `Map<String, String>`
and `List<...>` decoding depend on. The release build type sets
`consumerProguardFiles 'proguard-rules.pro'`, so these rules also ship to
consuming apps. No new rules are needed.

**Fixture drift.** The payload tracks the frontend contract. Before Plan 3 is published, re-capture `report_response_full.json` from a live scan and re-run this suite; a diff surfaces as a test failure rather than a rendering bug in Earthlink's app.
