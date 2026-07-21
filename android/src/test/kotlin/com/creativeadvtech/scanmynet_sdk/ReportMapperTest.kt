package com.creativeadvtech.scanmynet_sdk

import com.creative.tools.rest.dto.response.ChannelCongestionDto
import com.creative.tools.rest.dto.response.CustomerDetailsDto
import com.creative.tools.rest.dto.response.InternetSpeedDto
import com.creative.tools.rest.dto.response.ReportDto
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
}
