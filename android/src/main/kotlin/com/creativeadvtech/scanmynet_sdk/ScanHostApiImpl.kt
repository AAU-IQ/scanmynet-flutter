package com.creativeadvtech.scanmynet_sdk

import android.content.Context

/**
 * Skeleton [ScanHostApi] implementation.
 *
 * The real wiring to `com.creative.tools.network.scan.NetworkScan` — building
 * the step-builder, subscribing to the RxJava `scan()` `Single`, and forwarding
 * SDK callbacks to [flutterApi] — lands in the **T2 [Android]** task. For now
 * every method is a documented no-op so the generated Pigeon code compiles and
 * links before the native SDK is added.
 */
class ScanHostApiImpl(
    private val context: Context,
    private val flutterApi: ScanFlutterApi,
) : ScanHostApi {

    override fun configure(config: ScanConfig) {
        // TODO(T2): NetworkScan.builder()
        //     .context(context).userKey(config.userKey).apiKey(config.apiKey)
        //     .appName(config.appName).baseUrl(config.baseUrl)
        //     .progressCallback { flutterApi.onProgress(it.toPigeon()) { } }
        //     .resultCallback { ... }.debugCallback { ... }.errorCallback { ... }
        //     .build()   // store the instance; do NOT subscribe here
    }

    override fun startScan() {
        // TODO(T2): subscribe to networkScan.scan() on Schedulers.io(); hop to
        //     the main thread, then forward onSuccess -> flutterApi.onFinished,
        //     onError -> flutterApi.onError. Retain the Disposable.
    }

    override fun cancel() {
        // TODO(T2): no native cancel in this fork — dispose the subscription as
        //     a best-effort cancel.
    }

    /** Releases native resources when the engine detaches. */
    fun dispose() {
        // TODO(T2): dispose the CompositeDisposable / release the NetworkScan.
    }
}
