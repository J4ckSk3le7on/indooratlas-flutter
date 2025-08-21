package com.indooratlas.flutter

import android.Manifest
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.indooratlas.android.sdk.IALocation
import com.indooratlas.android.sdk.IALocationRequest
import com.indooratlas.android.sdk.IAOrientationRequest
import com.indooratlas.android.sdk.IALocationListener
import com.indooratlas.android.sdk.IALocationManager
import com.indooratlas.android.sdk.IARegion
import com.indooratlas.android.sdk.IAOrientationListener
import com.indooratlas.android.sdk.IAWayfindingListener
import com.indooratlas.android.sdk.IAGeofenceListener
import com.indooratlas.android.sdk.IAGeofenceEvent
import com.indooratlas.android.sdk.IAPOI
import com.indooratlas.android.sdk.IARoute
import com.indooratlas.android.sdk.resources.IAFloorPlan
import com.indooratlas.android.sdk.resources.IALatLng
import com.indooratlas.android.sdk.resources.IAVenue
import android.util.Log

// Lightweight wrapper result class (not used but kept for future)
open class IAFlutterResult

// Conversion helpers
private fun IAPOI2Map(poi: IAPOI): Map<String, Any?> {
    return mapOf(
        "type" to "Feature",
        "id" to poi.id,
        "properties" to mapOf(
            "name" to poi.name,
            "floor" to poi.floor,
            "payload" to poi.payload?.toString()
        ),
        "geometry" to mapOf(
            "type" to "Point",
            "coordinates" to listOf(poi.location.longitude, poi.location.latitude)
        )
    )
}

private fun IAFloorplan2Map(floorplan: IAFloorPlan): Map<String, Any?> {
    return mapOf(
        "id" to floorplan.id,
        "name" to floorplan.name ?: "",
        "url" to floorplan.url ?: "",
        "floorLevel" to floorplan.floorLevel,
        "bearing" to floorplan.bearing,
        "bitmapWidth" to floorplan.bitmapWidth,
        "bitmapHeight" to floorplan.bitmapHeight,
        "widthMeters" to floorplan.widthMeters,
        "heightMeters" to floorplan.heightMeters,
        "metersToPixels" to floorplan.metersToPixels,
        "pixelsToMeters" to floorplan.pixelsToMeters,
        "bottomLeft" to listOf(floorplan.bottomLeft.longitude, floorplan.bottomLeft.latitude),
        "bottomRight" to listOf(floorplan.bottomRight.longitude, floorplan.bottomRight.latitude),
        "center" to listOf(floorplan.center.longitude, floorplan.center.latitude),
        "topLeft" to listOf(floorplan.topLeft.longitude, floorplan.topLeft.latitude),
        "topRight" to listOf(floorplan.topRight.longitude, floorplan.topRight.latitude)
    )
}

private fun IARegion2Map(region: IARegion): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>(
        "regionId" to region.id,
        "timestamp" to region.timestamp,
        "regionType" to region.type
    )
    if (region.floorPlan != null) {
        map["floorPlan"] = IAFloorplan2Map(region.floorPlan)
    }
    // venue omitted for brevity unless needed
    return map
}

private fun IALocation2Map(location: IALocation): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>(
        "latitude" to location.latitude,
        "longitude" to location.longitude,
        "accuracy" to location.accuracy,
        "altitude" to location.altitude,
        "heading" to location.bearing,
        "floorCertainty" to location.floorCertainty,
        "flr" to location.floorLevel,
        "velocity" to location.toLocation().speed,
        "timestamp" to location.time
    )

    if (location.region != null) {
        map["region"] = IARegion2Map(location.region)
        val fp = location.region.floorPlan
        if (fp != null) {
            try {
                val point = fp.coordinateToPoint(location.latLngFloor)
                map["pix_x"] = point.x
                map["pix_y"] = point.y
            } catch (e: Exception) {
                // ignore if conversion fails (still send lat/lon)
            }
        }
    }
    return map
}

// Engine that talks to IndoorAtlas SDK
class IAFlutterEngine(private val context: Context, private val channel: MethodChannel) :
    IALocationListener, IAOrientationListener, IAGeofenceListener, IAWayfindingListener {

    private val handler = Handler(Looper.getMainLooper())
    private var locationManager: IALocationManager? = null
    private var locationRequest = IALocationRequest.create()
    private var orientationRequest = IAOrientationRequest(1.0, 1.0)
    private var locationServiceRunning = false

    private val TAG = "IAFlutterEngine"

    fun initialize(pluginVersion: String, apiKey: String, endpoint: String?) {
        handler.post {
            val bundle = Bundle(2)
            bundle.putString(IALocationManager.EXTRA_API_KEY, apiKey)
            bundle.putString(IALocationManager.EXTRA_API_SECRET, "not-used-in-flutter")
            bundle.putString("com.indooratlas.android.sdk.intent.extras.wrapperName", "flutter")
            bundle.putString("com.indooratlas.android.sdk.intent.extras.wrapperVersion", pluginVersion)
            if (!endpoint.isNullOrEmpty()) bundle.putString("com.indooratlas.android.sdk.intent.extras.restEndpoint", endpoint)
            // recreate manager
            locationManager?.destroy()
            locationManager = IALocationManager.create(context, bundle)
            Log.d(TAG, "IndoorAtlas initialized")
        }
    }

    fun requestPermissions(activityBinding: ActivityPluginBinding?) {
        // This plugin can't insert manifest entries; app must declare permissions.
        // We can request runtime permissions if we have an activity binding (caller must pass it)
        activityBinding?.activity?.let { activity ->
            val perms = mutableListOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,
                Manifest.permission.ACCESS_WIFI_STATE,
                Manifest.permission.CHANGE_WIFI_STATE,
                Manifest.permission.INTERNET
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // BLUETOOTH_SCAN required if targetSdk >= 31 (app-level). We request it if running on S+.
                perms.add(Manifest.permission.BLUETOOTH_SCAN)
            }
            activity.requestPermissions(perms.toTypedArray(), 444444)
        }
    }

    fun getTraceId(): String {
        return locationManager?.getExtraInfo()?.traceId ?: ""
    }

    override fun onStatusChanged(provider: String, status: Int, bundle: Bundle?) {
        val mapped = when (status) {
            IALocationManager.STATUS_OUT_OF_SERVICE -> 0
            IALocationManager.STATUS_TEMPORARILY_UNAVAILABLE -> 1
            IALocationManager.STATUS_AVAILABLE -> 2
            IALocationManager.STATUS_LIMITED -> 3
            else -> 0
        }
        channel.invokeMethod("onStatusChanged", listOf(mapped))
    }

    override fun onLocationChanged(location: IALocation) {
        handler.post {
            channel.invokeMethod("onLocationChanged", listOf(IALocation2Map(location)))
        }
    }

    override fun onEnterRegion(region: IARegion) {
        handler.post { channel.invokeMethod("onEnterRegion", listOf(IARegion2Map(region))) }
    }

    override fun onExitRegion(region: IARegion) {
        handler.post { channel.invokeMethod("onExitRegion", listOf(IARegion2Map(region))) }
    }

    override fun onOrientationChange(timestamp: Long, quaternion: DoubleArray) {
        handler.post {
            channel.invokeMethod(
                "onOrientationChanged",
                listOf(timestamp, quaternion[0], quaternion[1], quaternion[2], quaternion[3])
            )
        }
    }

    override fun onHeadingChanged(timestamp: Long, heading: Double) {
        handler.post { channel.invokeMethod("onHeadingChanged", listOf(timestamp, heading)) }
    }

    // wayfinding + geofence callbacks left empty/quiet — widget will not use them per requirement
    override fun onWayfindingUpdate(route: IARoute) {
        // intentionally ignored for this plugin version (widget only needs map/position/heading)
    }

    override fun onGeofencesTriggered(event: IAGeofenceEvent) {
        // ignored
    }

    fun startPositioning() {
        handler.post {
            locationManager?.registerRegionListener(this)
            locationManager?.registerOrientationListener(orientationRequest, this)
            locationManager?.requestLocationUpdates(locationRequest, this)
            locationServiceRunning = true
            Log.d(TAG, "startPositioning called")
        }
    }

    fun stopPositioning() {
        handler.post {
            locationManager?.removeLocationUpdates(this)
            locationManager?.unregisterOrientationListener(this)
            locationManager?.unregisterRegionListener(this)
            locationServiceRunning = false
            Log.d(TAG, "stopPositioning called")
        }
    }

    fun setOutputThresholds(distanceMeters: Double?, intervalSeconds: Double?) {
        handler.post {
            val running = locationServiceRunning
            if (running) stopPositioning()
            if (distanceMeters != null && distanceMeters >= 0) locationRequest.setSmallestDisplacement(distanceMeters.toFloat())
            if (intervalSeconds != null && intervalSeconds >= 0) locationRequest.setFastestInterval((intervalSeconds * 1000).toLong())
            if (running) startPositioning()
        }
    }

    fun setPositioningMode(modeIndex: Int?) {
        handler.post {
            val prio = when (modeIndex) {
                0 -> IALocationRequest.PRIORITY_HIGH_ACCURACY
                1 -> IALocationRequest.PRIORITY_LOW_POWER
                2 -> IALocationRequest.PRIORITY_CART_MODE
                else -> IALocationRequest.PRIORITY_HIGH_ACCURACY
            }
            locationRequest.setPriority(prio)
        }
    }

    fun lockIndoors(locked: Boolean?) {
        handler.post { locationManager?.lockIndoors(locked ?: true) }
    }

    fun lockFloor(floor: Int?) {
        handler.post { if (floor != null) locationManager?.lockFloor(floor) }
    }

    fun unlockFloor() {
        handler.post { locationManager?.unlockFloor() }
    }

    fun setSensitivities(orientationSensitivity: Double?, headingSensitivity: Double?) {
        handler.post {
            orientationRequest = IAOrientationRequest(headingSensitivity ?: 1.0, orientationSensitivity ?: 1.0)
            locationManager?.unregisterOrientationListener(this)
            locationManager?.registerOrientationListener(orientationRequest, this)
        }
    }

    fun detach() {
        handler.post {
            locationManager?.destroy()
            locationManager = null
        }
    }
}

// Actual plugin class
class IAFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var engineImpl: IAFlutterEngine
    private var activityBinding: ActivityPluginBinding? = null

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.indooratlas.flutter")
        channel.setMethodCallHandler(this)
        engineImpl = IAFlutterEngine(binding.applicationContext, channel)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        engineImpl.detach()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
    }

    override fun onDetachedFromActivity() {
        activityBinding = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "initialize" -> {
                    val args = call.arguments as List<*>
                    val pluginVersion = args[0] as String
                    val apiKey = args[1] as String
                    val endpoint = args[2] as? String ?: ""
                    engineImpl.initialize(pluginVersion, apiKey, endpoint)
                    result.success(null)
                }
                "requestPermissions" -> {
                    engineImpl.requestPermissions(activityBinding)
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
                    engineImpl.lockIndoors(call.arguments as Boolean?)
                    result.success(null)
                }
                "lockFloor" -> {
                    engineImpl.lockFloor((call.arguments as Number?)?.toInt())
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
                else -> {
                    result.notImplemented()
                }
            }
        } catch (e: Exception) {
            result.error("plugin_error", e.message, null)
        }
    }
}
