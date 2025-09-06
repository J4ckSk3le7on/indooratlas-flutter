package com.indooratlas.flutter

import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import android.Manifest
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log

// Importaciones de IndoorAtlas
import com.indooratlas.android.sdk.IALocation
import com.indooratlas.android.sdk.IALocationRequest
import com.indooratlas.android.sdk.IAOrientationRequest
import com.indooratlas.android.sdk.IALocationListener
import com.indooratlas.android.sdk.IALocationManager
import com.indooratlas.android.sdk.IARegion
import com.indooratlas.android.sdk.IARoute
import com.indooratlas.android.sdk.IAOrientationListener
import com.indooratlas.android.sdk.IAGeofenceListener
import com.indooratlas.android.sdk.IAGeofenceEvent
import com.indooratlas.android.sdk.IAPOI
import com.indooratlas.android.sdk.resources.IAFloorPlan
import com.indooratlas.android.sdk.resources.IALatLng
import com.indooratlas.android.sdk.resources.IAVenue


class IAFlutterPlugin: FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {
    private lateinit var _engineImpl: IAFlutterEngine
    private lateinit var _channel: MethodChannel
    private var _activityBinding: ActivityPluginBinding? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        _channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.indooratlas.flutter")
        _channel.setMethodCallHandler(this)
        _engineImpl = IAFlutterEngine(flutterPluginBinding.applicationContext, _channel)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        _channel.setMethodCallHandler(null)
        _engineImpl.detach()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        _activityBinding = binding
        _activityBinding?.addRequestPermissionsResultListener(this)
        _engineImpl.activityBinding = _activityBinding
    }

    override fun onDetachedFromActivityForConfigChanges() {
        _engineImpl.activityBinding = null
        _activityBinding?.removeRequestPermissionsResultListener(this)
        _activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        _activityBinding = binding
        _activityBinding?.addRequestPermissionsResultListener(this)
        _engineImpl.activityBinding = _activityBinding
    }

    override fun onDetachedFromActivity() {
        _engineImpl.activityBinding = null
        _activityBinding?.removeRequestPermissionsResultListener(this)
        _activityBinding = null
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray): Boolean {
        return _engineImpl.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        try {
            when (call.method) {
                "initialize" -> {
                    val args = call.arguments as List<*>
                    val pluginVersion = args[0] as String
                    val apiKey = args[1] as String
                    val endpoint = (args[2] as? String) ?: ""
                    _engineImpl.initialize(pluginVersion, apiKey, endpoint)
                    result.success(null)
                }
                "requestPermissions" -> {
                    _engineImpl.requestPermissions()
                    result.success(null)
                }
                "startPositioning" -> {
                    _engineImpl.startPositioning()
                    result.success(null)
                }
                "stopPositioning" -> {
                    _engineImpl.stopPositioning()
                    result.success(null)
                }
                "setOutputThresholds" -> {
                    val args = call.arguments as List<*>
                    val distance = (args[0] as Number?)?.toDouble()
                    val interval = (args[1] as Number?)?.toDouble()
                    _engineImpl.setOutputThresholds(distance, interval)
                    result.success(null)
                }
                "setPositioningMode" -> {
                    val idx = (call.arguments as Number?)?.toInt() ?: 0
                    _engineImpl.setPositioningMode(idx)
                    result.success(null)
                }
                "lockIndoors" -> {
                    _engineImpl.lockIndoors(call.arguments as Boolean)
                    result.success(null)
                }
                "lockFloor" -> {
                    _engineImpl.lockFloor((call.arguments as Number?)?.toInt() ?: 0)
                    result.success(null)
                }
                "unlockFloor" -> {
                    _engineImpl.unlockFloor()
                    result.success(null)
                }
                "setSensitivities" -> {
                    val args = call.arguments as List<*>
                    val ori = (args[0] as Number?)?.toDouble()
                    val head = (args[1] as Number?)?.toDouble()
                    _engineImpl.setSensitivities(ori, head)
                    result.success(null)
                }
                "getTraceId" -> {
                    result.success(_engineImpl.getTraceId())
                }
                "requestGeofences" -> {
                    val geofenceIds = (call.arguments as List<*>).map { it as String }
                    _engineImpl.requestGeofences(geofenceIds)
                    result.success(null)
                }
                "removeGeofences" -> {
                    _engineImpl.removeGeofences()
                    result.success(null)
                }
                "getCurrentGeofences" -> {
                    result.success(_engineImpl.getCurrentGeofences())
                }
                "startWayfinding" -> {
                    val args = call.arguments as List<*>
                    val lat = (args[0] as Number?)?.toDouble()
                    val lon = (args[1] as Number?)?.toDouble()
                    val floor = (args[2] as Number?)?.toInt()
                    val mode = if (args.size > 3) (args[3] as Number?)?.toInt() else null
                    _engineImpl.startWayfinding(lat, lon, floor, mode)
                    result.success(null)
                }
                "stopWayfinding" -> {
                    _engineImpl.stopWayfinding()
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