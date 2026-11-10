package com.creativeadvtech.scanmynet_sdk

import com.creative.tools.rest.dto.response.ChannelCongestionDto
import com.creative.tools.rest.dto.response.CustomerDetailsDto
import com.creative.tools.rest.dto.response.DnsQualityDto
import com.creative.tools.rest.dto.response.InternetSpeedDto
import com.creative.tools.rest.dto.response.RecommendedActionDto
import com.creative.tools.rest.dto.response.ReportDto
import com.creative.tools.rest.dto.response.UserConnectionDto
import com.creative.tools.rest.dto.response.WifiNetworkResultDto
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

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

    @Test
    fun `maps the ping status and its colour for each connection quality entry`() {
        val dto = ReportDto(
            connection_quality = listOf(
                DnsQualityDto(
                    dns_name = "192.168.1.1", is_subscriber_router = true,
                    ping_quality = "poor", packet_loss_quality = "excellent",
                    ping_quality_color = "red", packet_loss_quality_color = "green",
                ),
            ),
        )

        val entry = dto.toPigeon().connectionQuality!!.single()

        assertEquals("poor", entry.pingQuality)
        assertEquals("excellent", entry.packetLossQuality)
        assertEquals("red", entry.pingQualityColor)
        assertEquals("green", entry.packetLossQualityColor)
    }

    @Test
    fun `a router that answered nothing keeps a null ping rating`() {
        val entry = DnsQualityDto(dns_name = "router", packet_loss_quality = "poor", packet_loss_quality_color = "red")
            .toPigeon()

        assertNull(entry.pingQuality)
        assertNull(entry.pingQualityColor)
        assertEquals("poor", entry.packetLossQuality)
    }

    @Test
    fun `maps recommended actions with their texts by language`() {
        val dto = ReportDto(
            recommended_actions = listOf(
                RecommendedActionDto(
                    key = "delay_and_loss", priority = 2L, technical_state = "High Ping + Packet Loss",
                    title = mapOf("en" to "Delay and data loss", "ar" to "تأخير وفقدان في البيانات"),
                    message = mapOf("en" to "m", "ar" to "ر"),
                    recommended_action = mapOf("en" to "Run the scan again.", "ar" to "أعد الفحص."),
                ),
            ),
        )

        val action = dto.toPigeon().recommendedActions!!.single()

        assertEquals("delay_and_loss", action.key)
        assertEquals(2L, action.priority)
        assertEquals("High Ping + Packet Loss", action.technicalState)
        assertEquals("Delay and data loss", action.title!!["en"])
        assertEquals("تأخير وفقدان في البيانات", action.title!!["ar"])
        assertEquals("أعد الفحص.", action.recommendedAction!!["ar"])
    }

    @Test
    fun `maps No instructions through, and an empty list stays empty`() {
        val pigeon = ReportDto(
            recommended_actions = emptyList(),
            no_instructions = mapOf("en" to "No instructions", "ar" to "لا يوجد تعليمات"),
        ).toPigeon()

        assertEquals(0, pigeon.recommendedActions!!.size)
        assertEquals("No instructions", pigeon.noInstructions!!["en"])
        assertEquals("لا يوجد تعليمات", pigeon.noInstructions!!["ar"])
    }

    @Test
    fun `an older backend report maps both to null`() {
        val pigeon = ReportDto().toPigeon()

        assertNull(pigeon.recommendedActions)
        assertNull(pigeon.noInstructions)
    }

    @Test
    fun `a text with a null value is dropped, not sent`() {
        // Gson can hand back a null inside a Map<String, String>; the channel's map has no null values.
        @Suppress("UNCHECKED_CAST")
        val texts = mapOf("en" to "Hello", "ar" to null) as Map<String, String>

        val action = RecommendedActionDto(key = "x", title = texts).toPigeon()

        assertEquals(mapOf("en" to "Hello"), action.title)
    }

    @Test
    fun `wifi frequency stays in GHz and signal in dBm, as the backend sends them`() {
        val wifi = WifiNetworkResultDto(frequency = 2.437, signal_strength = -45, channel_width = 20).toPigeon()

        // GHz (2.437, 5.18), never MHz (2437): the app that draws its own screen shows the number as it is.
        assertEquals(2.437, wifi.frequency!!, 0.0)
        assertEquals(-45L, wifi.signalStrength)
        assertEquals(5.18, WifiNetworkResultDto(frequency = 5.18).toPigeon().frequency!!, 0.0)
    }

    @Test
    fun `an unknown wifi frequency stays null, not 0`() {
        // iOS sends no frequency and Android sends null when it does not know it.
        assertNull(WifiNetworkResultDto().toPigeon().frequency)
        assertNull(UserConnectionDto().toPigeon().phoneWifiFrequency)
    }

    @Test
    fun `the phone's wifi frequency in the congestion block is GHz too`() {
        assertEquals(5.18, UserConnectionDto(phone_wifi_frequency = 5.18).toPigeon().phoneWifiFrequency!!, 0.0)
    }
}
