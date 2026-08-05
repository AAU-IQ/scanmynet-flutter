package com.creativeadvtech.scanmynet_sdk

import com.creative.tools.network.scan.builder.Environment

/**
 * Maps the Pigeon [ScanEnvironment] onto the native SDK's [Environment].
 *
 * The URLs themselves live in the SDK (`tools`), not here — this only recombines
 * the selector with the [ScanConfig.customBaseUrl] / [ScanConfig.customFrontendUrl]
 * fields, which the wire format has to carry separately because a Pigeon enum
 * cannot hold a runtime value.
 */
internal fun ScanConfig.toNativeEnvironment(): Environment = when (environment) {
    ScanEnvironment.DEV -> Environment.Dev
    ScanEnvironment.STAGING -> Environment.Staging
    // The schema documents production as the default when the host sends nil.
    ScanEnvironment.PRODUCTION, null -> Environment.Production
    ScanEnvironment.CUSTOM -> Environment.Custom(
        // Dart's `configure` rejects a blank root first; Environment.Custom
        // re-checks it, so this is a backstop for a host that reaches the Pigeon
        // API without going through ScanmynetSdk.
        serverRoot = customBaseUrl.orEmpty(),
        viewerRoot = customFrontendUrl,
    )
}
