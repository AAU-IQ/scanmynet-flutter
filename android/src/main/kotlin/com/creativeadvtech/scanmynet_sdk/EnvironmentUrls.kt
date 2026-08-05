package com.creativeadvtech.scanmynet_sdk

/**
 * Resolves a [ScanConfig] to the two base URLs the Android side needs.
 *
 * Android is the platform where the plugin — not the native SDK — owns this
 * mapping: `NetworkScan.builder().baseUrl(String)` takes an arbitrary root, so
 * the environment is turned into a URL *here*. (On iOS the native SDK owns its
 * own `Environment`, and the bridge only forwards the selector.)
 *
 * Kept out of `ScanHostApiImpl` so it can be unit-tested without an Android
 * runtime or a `NetworkScan`.
 */

/** Applied when the host sends no environment — the schema's documented default. */
internal const val DEFAULT_BASE_URL = "https://scanmynet.earthlink.iq/"
internal const val DEFAULT_FRONTEND_URL = "https://scanmynet.earthlink.iq/"

/**
 * Retrofit base URL. `ReportApi` declares its paths relative (`api/v1/report/`),
 * so this must be the server root AND must keep its trailing slash — Retrofit
 * throws `IllegalArgumentException` on a base URL without one.
 */
internal fun ScanConfig.toBaseUrl(): String = when (environment) {
    ScanEnvironment.DEV -> "https://scanmynet-backend.dev.kvm.creativeadvtech.ml/"
    ScanEnvironment.STAGING -> "https://scanmynet-backend.stg.kvm.creativeadvtech.ml/"
    ScanEnvironment.PRODUCTION, null -> DEFAULT_BASE_URL
    ScanEnvironment.CUSTOM -> requireCustomBaseUrl().asUrlRoot()
}

/**
 * Report-viewer root. The backend returns a report's `verification_token` but not
 * a usable viewer link, so the shareable URL is assembled from this plus the token.
 */
internal fun ScanConfig.toFrontendUrl(): String = when (environment) {
    ScanEnvironment.DEV -> "https://scanmynet.dev.kvm.creativeadvtech.ml/"
    ScanEnvironment.STAGING -> "https://scanmynet.stg.kvm.creativeadvtech.ml/"
    ScanEnvironment.PRODUCTION, null -> DEFAULT_FRONTEND_URL
    // Operators who self-host the backend usually serve the viewer from the same
    // origin, so the base URL is the sensible fallback — never ours, which would
    // leak their report tokens onto our domain.
    ScanEnvironment.CUSTOM ->
        customFrontendUrl?.takeIf { it.isNotBlank() }?.asUrlRoot()
            ?: requireCustomBaseUrl().asUrlRoot()
}

/**
 * Dart's `configure` rejects this pairing first; this is the backstop for a host
 * that reaches the Pigeon API without going through `ScanmynetSdk`.
 */
private fun ScanConfig.requireCustomBaseUrl(): String =
    customBaseUrl?.takeIf { it.isNotBlank() }
        ?: throw IllegalArgumentException(
            "ScanEnvironment.CUSTOM requires customBaseUrl, e.g. " +
                "https://smn.example.com/",
        )

/**
 * Normalises an operator-supplied server root to exactly one trailing slash.
 * These are typed by hand, so they arrive as `https://h`, `https://h/`, or with
 * stray whitespace.
 */
private fun String.asUrlRoot(): String = trim().trimEnd('/') + "/"
