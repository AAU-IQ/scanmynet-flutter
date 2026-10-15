package com.creativeadvtech.scanmynet_sdk

import com.creative.tools.network.scan.ScanPreconditionException

/**
 * The terminal error of `NetworkScan.scan()` -> Pigeon [ScanError].
 *
 * Two things end a scan with an error: the scan was refused before it started because the device
 * is not on an Al-Watani Wi-Fi network ([ScanErrorKind.NOT_AL_WATANI]), or the finished report could
 * not be submitted ([ScanErrorKind.SUBMISSION]). Neither ran any step, or all of them did, so
 * [ScanError.step] and [ScanError.serviceType] are always null here.
 */
internal fun Throwable.toTerminalScanError(): ScanError = ScanError(
    kind = if (this is ScanPreconditionException) ScanErrorKind.NOT_AL_WATANI else ScanErrorKind.SUBMISSION,
    message = message ?: toString(),
    step = null,
    serviceType = null,
)
