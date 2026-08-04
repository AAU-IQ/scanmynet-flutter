package com.creativeadvtech.scanmynet_sdk

import okhttp3.HttpUrl.Companion.toHttpUrl
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

/**
 * The Android environment -> URL mapping. On Android the plugin owns this
 * mapping (the native `NetworkScan` builder takes an arbitrary base URL), so
 * these tests cover the whole custom-backend path short of the socket.
 */
class EnvironmentUrlsTest {

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

    // --- the endpoints the native SDK declares relative to the base URL -------
    // Verified against com.creative.tools.rest.services.ReportApi in tools-1.1.
    private val reportPath = "api/v1/report/"
    private val dnsConfigPath = "api/v1/scan_configs/dns_config"

    @Test
    fun `custom environment routes the report POST to the operator's host`() {
        val base = config(ScanEnvironment.CUSTOM, "https://smn.example.com/").toBaseUrl()

        // Retrofit resolves @POST paths against the base URL exactly like this.
        assertEquals(
            "https://smn.example.com/api/v1/report/",
            base.toHttpUrl().resolve(reportPath).toString(),
        )
        assertEquals(
            "https://smn.example.com/api/v1/scan_configs/dns_config",
            base.toHttpUrl().resolve(dnsConfigPath).toString(),
        )
    }

    @Test
    fun `custom base URL keeps a trailing slash so Retrofit accepts it`() {
        // Retrofit rejects a base URL that does not end in '/', and silently drops
        // the last path segment when resolving against one that does not.
        assertEquals(
            "https://smn.example.com/",
            config(ScanEnvironment.CUSTOM, "https://smn.example.com").toBaseUrl(),
        )
        assertEquals(
            "https://smn.example.com/",
            config(ScanEnvironment.CUSTOM, "  https://smn.example.com///  ").toBaseUrl(),
        )
    }

    @Test
    fun `custom base URL under a path prefix keeps the prefix`() {
        val base = config(ScanEnvironment.CUSTOM, "https://example.com/smn").toBaseUrl()

        assertEquals(
            "https://example.com/smn/api/v1/report/",
            base.toHttpUrl().resolve(reportPath).toString(),
        )
    }

    @Test
    fun `custom frontend URL is used for the report viewer link when given`() {
        assertEquals(
            "https://portal.example.com/",
            config(
                ScanEnvironment.CUSTOM,
                customBaseUrl = "https://api.example.com/",
                customFrontendUrl = "https://portal.example.com",
            ).toFrontendUrl(),
        )
    }

    @Test
    fun `custom viewer falls back to the base URL, never to our production host`() {
        val frontend = config(
            ScanEnvironment.CUSTOM,
            customBaseUrl = "https://smn.example.com/",
            customFrontendUrl = "   ",
        ).toFrontendUrl()

        assertEquals("https://smn.example.com/", frontend)
        // A leaked fallback here would put the operator's verification_token on
        // our domain — the specific bug this assertion guards.
        assertEquals(false, frontend == DEFAULT_FRONTEND_URL)
    }

    @Test
    fun `custom environment without a base URL is rejected`() {
        assertFailsWith<IllegalArgumentException> {
            config(ScanEnvironment.CUSTOM).toBaseUrl()
        }
        assertFailsWith<IllegalArgumentException> {
            config(ScanEnvironment.CUSTOM, customBaseUrl = " ").toBaseUrl()
        }
    }

    @Test
    fun `built-in environments are unchanged`() {
        assertEquals(
            "https://scanmynet-backend.dev.kvm.creativeadvtech.ml/",
            config(ScanEnvironment.DEV).toBaseUrl(),
        )
        assertEquals(
            "https://scanmynet-backend.stg.kvm.creativeadvtech.ml/",
            config(ScanEnvironment.STAGING).toBaseUrl(),
        )
        assertEquals(DEFAULT_BASE_URL, config(ScanEnvironment.PRODUCTION).toBaseUrl())
        // A null environment still defaults to production, as the schema documents.
        assertEquals(DEFAULT_BASE_URL, config(null).toBaseUrl())
        assertEquals(DEFAULT_FRONTEND_URL, config(null).toFrontendUrl())
    }

    @Test
    fun `a custom base URL is ignored unless the environment selects it`() {
        assertEquals(
            DEFAULT_BASE_URL,
            config(ScanEnvironment.PRODUCTION, "https://smn.example.com/").toBaseUrl(),
        )
    }
}
