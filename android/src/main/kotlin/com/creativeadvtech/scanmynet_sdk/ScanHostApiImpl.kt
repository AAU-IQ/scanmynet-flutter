package com.creativeadvtech.scanmynet_sdk

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.creative.tools.network.scan.NetworkScan
import com.creative.tools.network.scan.models.NetworkScanError
import com.creative.tools.network.scan.models.NetworkScanProgress
import com.creative.tools.network.scan.models.NetworkScanResult
import com.creative.tools.network.scan.models.NetworkScanResultStatus
import com.creative.tools.network.scan.models.NetworkScanStep
import com.creative.tools.network.scan.toJson
import com.creative.tools.rest.dto.ReportResponseDto
import io.reactivex.rxjava3.disposables.CompositeDisposable
import io.reactivex.rxjava3.schedulers.Schedulers

/**
 * Bridges the Pigeon [ScanHostApi] (Dart -> native) onto the RouteThis
 * `com.creative.tools.network.scan.NetworkScan` SDK, and forwards the SDK's
 * callbacks back to Dart through [flutterApi].
 *
 * Threading: the SDK's progress/result/debug/error callbacks fire on the scan's
 * RxJava IO scheduler, and the `scan()` `Single` is subscribed on IO — but the
 * Pigeon channel must be invoked on the main thread. Every [flutterApi] call is
 * therefore funnelled through [onMain].
 */
class ScanHostApiImpl(
    private val context: Context,
    private val flutterApi: ScanFlutterApi,
) : ScanHostApi {


    private val mainHandler = Handler(Looper.getMainLooper())
    private val disposables = CompositeDisposable()
    private var networkScan: NetworkScan? = null

    /** Captured from the SDK's ResultCallback to enrich the terminal [ScanResult]. */
    private var lastResult: NetworkScanResult? = null

    /**
     * Frontend (report-viewer) base URL for the configured environment. The
     * backend's `ReportResponseDto.data` carries the report's `verification_token`
     * but not a usable viewer URL, so the terminal [ScanResult.reportUrl] is built
     * here from this base + the token — matching the native app (TestDebugActivity).
     */
    private var frontendBaseUrl: String = DEFAULT_FRONTEND_URL

    override fun configure(config: ScanConfig) {
        val incoming = config.schemaVersion
        if (incoming != null && incoming != SCHEMA_VERSION) {
            throw IllegalStateException(
                "Pigeon schema mismatch: Dart sent v$incoming, native expects " +
                    "v$SCHEMA_VERSION. Codecs are positional — a mismatched pair " +
                    "misreads fields silently. Rebuild the plugin's native binaries.",
            )
        }
        frontendBaseUrl = config.toFrontendUrl()
        networkScan = NetworkScan.builder()
            .context(context)
            .userKey(config.userKey.orEmpty())
            .apiKey(config.apiKey)
            .appName(config.appName.orEmpty())
            .baseUrl(config.toBaseUrl())
            .progressCallback { progress -> onMain { flutterApi.onProgress(progress.toPigeon()) {} } }
            .resultCallback { result -> lastResult = result }
            .debugCallback { report -> onMain { flutterApi.onDataPersisted(ScanReport(report.toJson())) {} } }
            .errorCallback { error -> onMain { flutterApi.onError(error.toPigeon()) {} } }
            .build()
    }

    override fun startScan() {
        val scan = networkScan
            ?: throw IllegalStateException("configure() must be called before startScan()")
        lastResult = null
        onMain { flutterApi.onStarted {} }
        disposables.add(
            scan.scan()
                .subscribeOn(Schedulers.io())
                .subscribe(
                    { response -> onMain { flutterApi.onFinished(response.toPigeon(lastResult)) {} } },
                    { error -> onMain { flutterApi.onError(error.toSubmissionError()) {} } },
                ),
        )
    }

    override fun cancel() {
        // This SDK fork has no native cancel; disposing the subscription stops
        // event delivery as a best-effort cancel (the native tests keep running
        // to completion in the background but their results are dropped).
        disposables.clear()
    }

    /** Releases native resources when the Flutter engine detaches. */
    fun dispose() {
        disposables.clear()
        networkScan = null
        lastResult = null
    }

    private fun onMain(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) block() else mainHandler.post(block)
    }

    // --- model mappers (native -> Pigeon) ------------------------------------

    private fun NetworkScanProgress.toPigeon() = ScanProgress(
        percent = percent.toDouble() * 100.0, // native percent is a 0..1 fraction
        currentStep = currentStep.toPigeon(),
        nextStep = nextStep.toPigeon(),
        label = null,
        durationMs = duration,
    )

    private fun ReportResponseDto.toPigeon(result: NetworkScanResult?) = ScanResult(
        reportUrl = buildReportUrl(data),
        status = result?.status?.toPigeon() ?: ScanResultStatus.SUCCESS,
        totalDurationMs = result?.duration,
        reportId = report_id,
        customerId = customer_id,
        report = report?.toPigeon(),
    )

    /**
     * Builds the full report-viewer URL Flutter opens as-is. The backend's `data`
     * is a malformed viewer link (e.g. `…mlview-report?verification_token=…`, no
     * `/#/`), so we pull the `verification_token` out and re-assemble it against
     * the environment's [frontendBaseUrl]. `substringAfter` is used instead of
     * `Uri.getQueryParameter` so the token is found whether it sits in the URL's
     * query or its `#/` fragment. If no token is present, `data` is passed through.
     */
    private fun buildReportUrl(data: String): String {
        val marker = "verification_token="
        if (!data.contains(marker)) return data
        val token = data.substringAfter(marker).substringBefore("&")
        return "${frontendBaseUrl}#/view-report/?verification_token=$token"
    }

    private fun NetworkScanError.toPigeon() = ScanError(
        kind = ScanErrorKind.PER_STEP,
        message = error?.message ?: error?.toString() ?: "unknown error",
        step = test.toPigeon(),
        serviceType = null,
    )

    private fun Throwable.toSubmissionError() = ScanError(
        kind = ScanErrorKind.SUBMISSION,
        message = message ?: toString(),
        step = null,
        serviceType = null,
    )

    private fun NetworkScanResultStatus.toPigeon() = when (this) {
        NetworkScanResultStatus.SUCCESS -> ScanResultStatus.SUCCESS
        NetworkScanResultStatus.ERROR_SUBMISSION_FAILED -> ScanResultStatus.SUBMISSION_FAILED
    }

    private fun NetworkScanStep.toPigeon() = when (this) {
        NetworkScanStep.SETUP -> ScanStep.SETUP
        NetworkScanStep.ROUTER_UPNP -> ScanStep.ROUTER_UPNP
        NetworkScanStep.CONNECTIVITY_TEST -> ScanStep.CONNECTIVITY_TEST
        NetworkScanStep.SPEED_TEST -> ScanStep.SPEED_TEST
        NetworkScanStep.PUBLIC_IP_FETCH -> ScanStep.PUBLIC_IP_FETCH
        NetworkScanStep.GPS_LOCATION_FETCH -> ScanStep.GPS_LOCATION_FETCH
        NetworkScanStep.TRACEROUTE -> ScanStep.TRACEROUTE
        NetworkScanStep.WIFI_CONGESTION_TEST -> ScanStep.WIFI_CONGESTION_TEST
        NetworkScanStep.WIFI_DISCOVERY -> ScanStep.WIFI_DISCOVERY
        NetworkScanStep.CONNECTION_QUALITY_TEST -> ScanStep.CONNECTION_QUALITY_TEST
        NetworkScanStep.LAN_DISCOVERY -> ScanStep.LAN_DISCOVERY
        NetworkScanStep.ADDITIONAL_DATA -> ScanStep.ADDITIONAL_DATA
        NetworkScanStep.RESULT_SUBMISSION -> ScanStep.RESULT_SUBMISSION
    }

    companion object {
        /** Must match `.schemaVersion` in Dart. */
        const val SCHEMA_VERSION = 3L
    }
}
