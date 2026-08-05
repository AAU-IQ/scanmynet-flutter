package com.creativeadvtech.scanmynet_sdk

import com.creative.tools.network.scan.builder.Environment
import okhttp3.HttpUrl.Companion.toHttpUrl
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotEquals

/**
 * Pigeon [ScanEnvironment] -> native [Environment]. The URLs are asserted through
 * the composed endpoint, since that is what the scan actually posts to.
 */
class ScanEnvironmentMapperTest {

    private fun config(
        environment: ScanEnvironment?,
        customBaseUrl: String? = null,
        customFrontendUrl: String? = null,
    ) = ScanConfig(
        apiKey = "k",
        environment = environment,
        customBaseUrl = customBaseUrl,
        customFrontendUrl = customFrontendUrl,
    )

    private val reportPath = "api/v1/report/"

    @Test
    fun `each selector maps to its native environment`() {
        assertEquals(Environment.Dev, config(ScanEnvironment.DEV).toNativeEnvironment())
        assertEquals(Environment.Staging, config(ScanEnvironment.STAGING).toNativeEnvironment())
        assertEquals(
            Environment.Production,
            config(ScanEnvironment.PRODUCTION).toNativeEnvironment(),
        )
    }

    @Test
    fun `a null environment defaults to production, as the schema documents`() {
        assertEquals(Environment.Production, config(null).toNativeEnvironment())
    }

    @Test
    fun `custom routes the report POST to the operator's host`() {
        val env = config(ScanEnvironment.CUSTOM, "https://smn.example.com/").toNativeEnvironment()

        // Retrofit resolves the SDK's relative @POST paths against baseUrl this way.
        assertEquals(
            "https://smn.example.com/api/v1/report/",
            env.baseUrl.toHttpUrl().resolve(reportPath).toString(),
        )
    }

    @Test
    fun `custom normalises a hand-typed root`() {
        assertEquals(
            "https://smn.example.com/",
            config(ScanEnvironment.CUSTOM, "  https://smn.example.com///  ")
                .toNativeEnvironment().baseUrl,
        )
    }

    @Test
    fun `custom viewer root is forwarded when given`() {
        assertEquals(
            "https://portal.example.com/",
            config(
                ScanEnvironment.CUSTOM,
                customBaseUrl = "https://api.example.com/",
                customFrontendUrl = "https://portal.example.com",
            ).toNativeEnvironment().frontendUrl,
        )
    }

    @Test
    fun `custom viewer falls back to the base URL, never to our production host`() {
        val env = config(
            ScanEnvironment.CUSTOM,
            customBaseUrl = "https://smn.example.com/",
            customFrontendUrl = "   ",
        ).toNativeEnvironment()

        assertEquals("https://smn.example.com/", env.frontendUrl)
        // A leak here would put the operator's verification_token on our domain.
        assertNotEquals(Environment.Production.frontendUrl, env.frontendUrl)
    }

    @Test
    fun `custom without a base URL is rejected`() {
        assertFailsWith<IllegalArgumentException> {
            config(ScanEnvironment.CUSTOM).toNativeEnvironment()
        }
        assertFailsWith<IllegalArgumentException> {
            config(ScanEnvironment.CUSTOM, customBaseUrl = " ").toNativeEnvironment()
        }
    }

    @Test
    fun `a custom base URL is ignored unless the environment selects it`() {
        assertEquals(
            Environment.Production,
            config(ScanEnvironment.PRODUCTION, "https://smn.example.com/").toNativeEnvironment(),
        )
    }
}
