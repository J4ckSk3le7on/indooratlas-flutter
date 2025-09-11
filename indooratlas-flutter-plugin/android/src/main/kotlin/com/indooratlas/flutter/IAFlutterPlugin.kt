package com.indooratlas.flutter

import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * IndoorAtlas Flutter Plugin
 * 
 * This plugin provides Flutter bindings for the IndoorAtlas SDK,
 * enabling indoor positioning and wayfinding capabilities.
 */
class IAFlutterPlugin: FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {
    
    companion object {
        private const val CHANNEL_NAME = "com.indooratlas.flutter"
    }
    
    private lateinit var engineImpl: IAFlutterEngine
    private lateinit var channel: MethodChannel
    private var activityBinding: ActivityPluginBinding? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        engineImpl = IAFlutterEngine(flutterPluginBinding.applicationContext, channel)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        engineImpl.detach()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        activityBinding?.addRequestPermissionsResultListener(this)
        engineImpl.activityBinding = activityBinding
    }

    override fun onDetachedFromActivityForConfigChanges() {
        engineImpl.activityBinding = null
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
        activityBinding?.addRequestPermissionsResultListener(this)
        engineImpl.activityBinding = activityBinding
    }

    override fun onDetachedFromActivity() {
        engineImpl.activityBinding = null
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray): Boolean {
        return engineImpl.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        try {
            when (call.method) {
                "initialize" -> {
                    val args = call.arguments as List<*>
                    val pluginVersion = args[0] as String
                    val apiKey = args[1] as String
                    val endpoint = (args[2] as? String) ?: ""
                    engineImpl.initialize(pluginVersion, apiKey, endpoint)
                    result.success(null)
                }
                "requestPermissions" -> {
                    engineImpl.requestPermissions()
                    result.success(null)
                }
                "startPositioning" -> {
                    engineImpl.startPositioning()
                    result.success(null)
                }
                "stopPositioning" -> {
                    engineImpl.stopPositioning()
                    result.success(null)
                }
                "setOutputThresholds" -> {
                    val args = call.arguments as List<*>
                    val distance = (args[0] as Number?)?.toDouble()
                    val interval = (args[1] as Number?)?.toDouble()
                    engineImpl.setOutputThresholds(distance, interval)
                    result.success(null)
                }
                "setPositioningMode" -> {
                    val idx = (call.arguments as Number?)?.toInt() ?: 0
                    engineImpl.setPositioningMode(idx)
                    result.success(null)
                }
                "lockIndoors" -> {
                    engineImpl.lockIndoors(call.arguments as Boolean)
                    result.success(null)
                }
                "lockFloor" -> {
                    engineImpl.lockFloor((call.arguments as Number?)?.toInt() ?: 0)
                    result.success(null)
                }
                "unlockFloor" -> {
                    engineImpl.unlockFloor()
                    result.success(null)
                }
                "setSensitivities" -> {
                    val args = call.arguments as List<*>
                    val ori = (args[0] as Number?)?.toDouble()
                    val head = (args[1] as Number?)?.toDouble()
                    engineImpl.setSensitivities(ori, head)
                    result.success(null)
                }
                "getTraceId" -> {
                    result.success(engineImpl.getTraceId())
                }
                "requestGeofences" -> {
                    val geofenceIds = (call.arguments as List<*>).map { it as String }
                    engineImpl.requestGeofences(geofenceIds)
                    result.success(null)
                }
                "removeGeofences" -> {
                    engineImpl.removeGeofences()
                    result.success(null)
                }
                "getCurrentGeofences" -> {
                    result.success(engineImpl.getCurrentGeofences())
                }
                "startWayfinding" -> {
                    val args = call.arguments as List<*>
                    val lat = (args[0] as Number?)?.toDouble()
                    val lon = (args[1] as Number?)?.toDouble()
                    val floor = (args[2] as Number?)?.toInt()
                    val mode = if (args.size > 3) (args[3] as Number?)?.toInt() else null
                    engineImpl.startWayfinding(lat, lon, floor, mode)
                    result.success(null)
                }
                "stopWayfinding" -> {
                    engineImpl.stopWayfinding()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            e.printStackTrace()
            result.error("plugin_exception", e.message, null)
        }
    }
}