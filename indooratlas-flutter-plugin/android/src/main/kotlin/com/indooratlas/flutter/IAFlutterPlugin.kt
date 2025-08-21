package com.indooratlas.flutter

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import com.indooratlas.android.sdk.*
import com.indooratlas.android.sdk.resources.IAFloorPlan
import com.indooratlas.android.sdk.resources.IAVenue
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener

// region Data Converters (Object to Map)
private fun IAGeofence2Map(geofence: IAGeofence): Map<String, Any> {
    val vertices = geofence.edges.map { listOf(it[0], it[1]) }
    return mapOf(
        "type" to "Feature",
        "id" to geofence.id,
        "properties" to mapOf(
            "name" to geofence.name,
            "floor" to geofence.floor,
            "payload" to (geofence.payload?.toString() ?: "")
        ),
        "geometry" to mapOf(
            "type" to "Polygon",
            "coordinates" to listOf(vertices)
        )
    )
}

private fun IAFloorplan2Map(floorplan: IAFloorPlan): Map<String, Any> {
    return mapOf(
        "id" to floorplan.id,
        "name" to floorplan.name,
        "url" to floorplan.url,
        "floorLevel" to floorplan.floorLevel,
        "bearing" to floorplan.bearing,
        "bitmapWidth" to floorplan.bitmapWidth,
        "bitmapHeight" to floorplan.bitmapHeight,
        "metersToPixels" to floorplan.metersToPixels,
        "center" to listOf(floorplan.center.longitude, floorplan.center.latitude)
    )
}

private fun IAVenue2Map(venue: IAVenue): Map<String, Any> {
    val map = mutableMapOf<String, Any>(
        "id" to venue.id,
        "name" to venue.name
    )
    val plans = venue.floorPlans.map { IAFloorplan2Map(it) }
    if (plans.isNotEmpty()) map["floorPlans"] = plans
    val fences = venue.geofences.map { IAGeofence2Map(it) }
    if (fences.isNotEmpty()) map["geofences"] = fences
    return map
}

private fun IARegion2Map(region: IARegion): Map<String, Any> {
    val map = mutableMapOf<String, Any>(
        "regionId" to region.id,
        "timestamp" to region.timestamp,
        "regionType" to region.type
    )
    region.floorPlan?.let { map["floorPlan"] = IAFloorplan2Map(it) }
    region.venue?.let { map["venue"] = IAVenue2Map(it) }
    return map
}

private fun IALocation2Map(location: IALocation): Map<String, Any> {
    val map = mutableMapOf<String, Any>(
        "latitude" to location.latitude,
        "longitude" to location.longitude,
        "accuracy" to location.accuracy,
        "altitude" to location.altitude,
        "heading" to location.bearing,
        "floorCertainty" to location.floorCertainty,
        "flr" to (location.floorLevel ?: 0),
        "velocity" to location.toLocation().speed,
        "timestamp" to location.time
    )
    location.region?.let { region ->
        map["region"] = IARegion2Map(region)
        region.floorPlan?.let { floorPlan ->
            val point = floorPlan.coordinateToPoint(location.latLngFloor)
            map["pix_x"] = point.x
            map["pix_y"] = point.y
        }
    }
    return map
}
// endregion

class IAFlutterEngine(
    private val context: Context,
    private val channel: MethodChannel
) : IALocationListener,
    IARegion.Listener,
    IAOrientationListener,
    IAGeofenceListener,
    RequestPermissionsResultListener {

    private val handler = Handler(Looper.getMainLooper())
    private var locationManager: IALocationManager? = null
    private var locationRequest = IALocationRequest.create()
    private var orientationRequest = IAOrientationRequest(1.0, 1.0)

    var activityBinding: ActivityPluginBinding? = null
        set(value) {
            field?.removeRequestPermissionsResultListener(this)
            value?.addRequestPermissionsResultListener(this)
            field = value
        }

    companion object {
        private const val PERMISSION_REQUEST_CODE = 444444
    }

    private fun getRequiredPermissions(): Array<String> {
        val permissions = mutableListOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissions.add(Manifest.permission.BLUETOOTH_SCAN)
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
        }
        return permissions.toTypedArray()
    }

    // region Listeners
    override fun onLocationChanged(location: IALocation) {
        channel.invokeMethod("onLocationChanged", IALocation2Map(location))
    }

    override fun onStatusChanged(provider: String, status: Int, extras: Bundle) {
        val mappedStatus = when (status) {
            IALocationManager.STATUS_OUT_OF_SERVICE -> 0
            IALocationManager.STATUS_TEMPORARILY_UNAVAILABLE -> 1
            IALocationManager.STATUS_AVAILABLE -> 2
            IALocationManager.STATUS_LIMITED -> 3
            else -> 0
        }
        channel.invokeMethod(
            "onStatusChanged",
            mapOf("status" to mappedStatus, "message" to (extras.getString("message") ?: ""))
        )
    }

    override fun onEnterRegion(region: IARegion) {
        channel.invokeMethod("onEnterRegion", IARegion2Map(region))
    }

    override fun onExitRegion(region: IARegion) {
        channel.invokeMethod("onExitRegion", IARegion2Map(region))
    }

    override fun onOrientationChange(timestamp: Long, quaternion: DoubleArray) {
        channel.invokeMethod(
            "onOrientationChanged", mapOf(
                "timestamp" to timestamp,
                "x" to quaternion[0], "y" to quaternion[1], "z" to quaternion[2], "w" to quaternion[3]
            )
        )
    }

    override fun onHeadingChanged(timestamp: Long, heading: Double) {
        channel.invokeMethod("onHeadingChanged", mapOf("timestamp" to timestamp, "heading" to heading))
    }

    override fun onGeofencesTriggered(event: IAGeofenceEvent) {
        event.triggers.forEach { trigger: IAGeofenceEvent.Trigger ->
            val type = if (trigger.transition == IAGeofence.GEOFENCE_TRANSITION_ENTER) "enter" else "exit"
            trigger.geofence?.let { geofence ->
                channel.invokeMethod(
                    "onGeofenceEvent", mapOf(
                        "geofence" to IAGeofence2Map(geofence),
                        "type" to type
                    )
                )
            }
        }
    }
    // endregion

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray): Boolean {
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            // channel.invokeMethod("onPermissionsResult", allGranted)
            return true
        }
        return false
    }

    // region Public API from Flutter
    fun initialize(apiKey: String, apiSecret: String) {
        handler.post {
            val extras = Bundle().apply {
                putString(IALocationManager.EXTRA_API_KEY, apiKey)
                putString(IALocationManager.EXTRA_API_SECRET, apiSecret)
            }
            locationManager?.destroy()
            locationManager = IALocationManager.create(context, extras)
            locationManager?.addGeofenceListener(this)
            requestPermissions()
        }
    }

    fun getTraceId(): String? {
        return locationManager?.extraInfo?.traceId
    }

    fun lockIndoors(locked: Boolean) {
        handler.post { locationManager?.lockIndoors(locked) }
    }

    fun lockFloor(floor: Int) {
        handler.post { locationManager?.lockFloor(floor) }
    }

    fun unlockFloor() {
        handler.post { locationManager?.unlockFloor() }
    }

    fun startPositioning() {
        handler.post {
            locationManager?.let {
                it.registerRegionListener(this)
                it.registerOrientationListener(orientationRequest, this)
                it.requestLocationUpdates(locationRequest, this)
            }
        }
    }

    fun stopPositioning() {
        handler.post {
            locationManager?.let {
                it.removeLocationUpdates(this)
                it.unregisterOrientationListener(this)
                it.unregisterRegionListener(this)
            }
        }
    }

    private fun requestPermissions() {
        activityBinding?.activity?.requestPermissions(getRequiredPermissions(), PERMISSION_REQUEST_CODE)
    }

    fun detach() {
        handler.post {
            locationManager?.destroy()
            locationManager = null
        }
    }
    // endregion
}

class IAFlutterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private var engine: IAFlutterEngine? = null
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.indooratlas.flutter")
        engine = IAFlutterEngine(binding.applicationContext, channel!!)
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        engine?.detach()
        engine = null
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: Result<Any?>) {
        when (call.method) {
            "initialize" -> {
                val apiKey = call.argument<String>("apiKey")
                val apiSecret = call.argument<String>("apiSecret")
                if (apiKey != null && apiSecret != null) {
                    engine?.initialize(apiKey, apiSecret)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGS", "apiKey or apiSecret is null", null)
                }
            }
            "getTraceId" -> result.success(engine?.getTraceId())
            "lockIndoors" -> {
                (call.arguments as? List<*>)?.getOrNull(0)?.let {
                    if (it is Boolean) engine?.lockIndoors(it)
                }
                result.success(null)
            }
            "lockFloor" -> {
                (call.arguments as? List<*>)?.getOrNull(0)?.let {
                    if (it is Int) engine?.lockFloor(it)
                }
                result.success(null)
            }
            "unlockFloor" -> {
                engine?.unlockFloor()
                result.success(null)
            }
            "startPositioning" -> {
                engine?.startPositioning()
                result.success(null)
            }
            "stopPositioning" -> {
                engine?.stopPositioning()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // region ActivityAware
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        engine?.activityBinding = binding
    }

    override fun onDetachedFromActivity() {
        engine?.activityBinding = null
    }



    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        engine?.activityBinding = binding
    }

    override fun onDetachedFromActivityForConfigChanges() {
        engine?.activityBinding = null
    }
    // endregion
}