package com.creativeadvtech.scanmynet_sdk

private const val TOKEN_MARKER = "verification_token="

/**
 * The full report-viewer URL Flutter opens as-is: `<frontendUrl>view-report?verification_token=<token>`.
 *
 * Older backends return a malformed viewer link in [data] (e.g. `…mlview-report?verification_token=…`,
 * no slash after the host), so the `verification_token` is pulled out and the link re-assembled
 * against [frontendUrl], the environment's viewer root (it ends in `/`). `substringAfter` is used
 * instead of `Uri.getQueryParameter` so the token is found wherever it sits in the string. If no
 * token is present, [data] is passed through.
 *
 * The portal routes by path, so the link has no `#`. Before 1.3.1 this built
 * `…/#/view-report/?…`, which a path-routed portal opens on its home page and then sends to the
 * login screen.
 */
internal fun reportViewerUrl(frontendUrl: String, data: String): String {
    if (!data.contains(TOKEN_MARKER)) return data
    val token = data.substringAfter(TOKEN_MARKER).substringBefore("&")
    return "${frontendUrl}view-report?verification_token=$token"
}
