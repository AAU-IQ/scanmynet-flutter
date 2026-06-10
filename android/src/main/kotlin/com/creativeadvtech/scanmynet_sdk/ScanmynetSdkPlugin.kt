package com.creativeadvtech.scanmynet_sdk

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * ScanMyNet plugin entry point.
 *
 * Registers the Pigeon-generated [ScanHostApi] handler (Dart -> native) and
 * constructs the [ScanFlutterApi] caller (native -> Dart) used to push scan
 * events back to Flutter.
 */
class ScanmynetSdkPlugin : FlutterPlugin {
    private var hostApi: ScanHostApiImpl? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val flutterApi = ScanFlutterApi(binding.binaryMessenger)
        hostApi = ScanHostApiImpl(binding.applicationContext, flutterApi)
        ScanHostApi.setUp(binding.binaryMessenger, hostApi)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        ScanHostApi.setUp(binding.binaryMessenger, null)
        hostApi?.dispose()
        hostApi = null
    }
}
