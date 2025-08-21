package com.indooratlas.flutter

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.EventChannel.StreamHandler

import com.indooratlas.android.sdk.IAGeofence
import com.indooratlas.android.sdk.IAGeofenceEvent
import com.indooratlas.android.sdk.IAGeofenceListener
import com.indooratlas.android.sdk.IALocation
import com.indooratlas.android.sdk.IALocationListener
import com.indooratlas.android.sdk.IALocationManager
import com.indooratlas.android.sdk.IALocationRequest
import com.indooratlas.android.sdk.IAOrientationListener
import com.indooratlas.android.sdk.IAOrientationRequest
import com.indooratlas.android.sdk.IARegion
import com.indooratlas.android.sdk.resources.IAFloorPlan
import com.indooratlas.android.sdk.resources.IAVenue

// -------------------------------
// Data Converters (Object -> Map)
// -------------------------------
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

// -------------------------------
// Puente de eventos (EventChannels)
// -------------------------------
private class IAEventBridge {
    @Volatile var statusSink: EventSink? = null
    @Volatile var locationSink: EventSink? = null
    @Volatile var regionSink: EventSink? = null
    @Volatile var geofenceSink: EventSink? = null
    @Volatile var orientationSink: EventSink? = null
    @Volatile var headingSink: EventSink? = null

    fun clearAll() {
        statusSink = null
        locationSink = null
        regionSink = null
        geofenceSink = null
        orientationSink = null
        headingSink = null
    }
}

// ---------------------------------
// Motor: puente con el SDK nativo
// ---------------------------------
private class IAFlutterEngine(
    private val context: Context,
    private val events: IAEventBridge
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

    // ----------------
    // Listeners
    // ----------------
    override fun onLocationChanged(location: IALocation) {
        val data = IALocation2Map(location)
        handler.post { events.locationSink?.success(data) }
    }

    override fun onStatusChanged(provider: String, status: Int, extras: Bundle) {
        val mappedStatus = when (status) {
            IALocationManager.STATUS_OUT_OF_SERVICE -> 0
            IALocationManager.STATUS_TEMPORARILY_UNAVAILABLE -> 1
            IALocationManager.STATUS_AVAILABLE -> 2
            IALocationManager.STATUS_LIMITED -> 3
            else -> 0
        }
        val msg = extras.getString("message") ?: ""
        handler.post { events.statusSink?.success(mapOf("status" to mappedStatus, "message" to msg)) }
    }

    override fun onEnterRegion(region: IARegion) {
        val payload = mapOf("enter" to true, "region" to IARegion2Map(region))
        handler.post { events.regionSink?.success(payload) }
    }

    override fun onExitRegion(region: IARegion) {
        val payload = mapOf("enter" to false, "region" to IARegion2Map(region))
        handler.post { events.regionSink?.success(payload) }
    }

    override fun onOrientationChange(timestamp: Long, quaternion: DoubleArray) {
        val data = mapOf(
            "timestamp" to timestamp,
            "x" to quaternion[0], "y" to quaternion[1], "z" to quaternion[2], "w" to quaternion[3]
        )
        handler.post { events.orientationSink?.success(data) }
    }

    override fun onHeadingChanged(timestamp: Long, heading: Double) {
        val data = mapOf("timestamp" to timestamp, "heading" to heading)
        handler.post { events.headingSink?.success(data) }
    }

    override fun onGeofencesTriggered(event: IAGeofenceEvent) {
        event.triggers.forEach { trigger ->
            val type = when (trigger.transition) {
                IAGeofence.GEOFENCE_TRANSITION_ENTER -> "enter"
                IAGeofence.GEOFENCE_TRANSITION_EXIT -> "exit"
                else -> "unknown"
            }
            trigger.geofence?.let { geofence ->
                val data = mapOf("type" to type, "geofence" to IAGeofence2Map(geofence))
                handler.post { events.geofenceSink?.success(data) }
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == PERMISSION_REQUEST_CODE) {
            // Puedes propagar a Dart si lo necesitas.
            return true
        }
        return false
    }

    // ----------------
    // API pública
    // ----------------
    fun initialize(apiKey: String, apiSecret: String) {
        handler.post {
            val extras = Bundle().apply {
                putString(IALocationManager.EXTRA_API_KEY, apiKey)
                putString(IALocationManager.EXTRA_API_SECRET, apiSecret)
            }
            locationManager?.destroy()
            locationManager = IALocationManager.create(context, extras)
            locationManager?.registerGeofenceListener(this)
            requestPermissions()
        }
    }

    fun getTraceId(): String? = locationManager?.extraInfo?.traceId

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
                it.unregisterGeofenceListener(this)
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
}

// ---------------------------------
// Plugin (Flutter Embedding V2)
// ---------------------------------
class IAFlutterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    private var engine: IAFlutterEngine? = null
    private var methodChannel: MethodChannel? = null
    private val events = IAEventBridge()

    // EventChannels
    private var statusCh: EventChannel? = null
    private var locationCh: EventChannel? = null
    private var regionCh: EventChannel? = null
    private var geofenceCh: EventChannel? = null
    private var orientationCh: EventChannel? = null
    private var headingCh: EventChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "com.indooratlas.flutter")
        methodChannel?.setMethodCallHandler(this)

        // Event channels
        statusCh = EventChannel(binding.binaryMessenger, "com.indooratlas.flutter/events/status")
        locationCh = EventChannel(binding.binaryMessenger, "com.indooratlas.flutter/events/location")
        regionCh = EventChannel(binding.binaryMessenger, "com.indooratlas.flutter/events/region")
        geofenceCh = EventChannel(binding.binaryMessenger, "com.indooratlas.flutter/events/geofence")
        orientationCh = EventChannel(binding.binaryMessenger, "com.indooratlas.flutter/events/orientation")
        headingCh = EventChannel(binding.binaryMessenger, "com.indooratlas.flutter/events/heading")

        val mkHandler = { sinkSetter: (EventSink?) -> Unit ->
            object : StreamHandler {
                override fun onListen(arguments: Any?, events: EventSink?) { sinkSetter(events) }
                override fun onCancel(arguments: Any?) { sinkSetter(null) }
            }
        }

        statusCh?.setStreamHandler(mkHandler { events.statusSink = it })
        locationCh?.setStreamHandler(mkHandler { events.locationSink = it })
        regionCh?.setStreamHandler(mkHandler { events.regionSink = it })
        geofenceCh?.setStreamHandler(mkHandler { events.geofenceSink = it })
        orientationCh?.setStreamHandler(mkHandler { events.orientationSink = it })
        headingCh?.setStreamHandler(mkHandler { events.headingSink = it })

        engine = IAFlutterEngine(binding.applicationContext, events)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null

        statusCh?.setStreamHandler(null); statusCh = null
        locationCh?.setStreamHandler(null); locationCh = null
        regionCh?.setStreamHandler(null); regionCh = null
        geofenceCh?.setStreamHandler(null); geofenceCh = null
        orientationCh?.setStreamHandler(null); orientationCh = null
        headingCh?.setStreamHandler(null); headingCh = null
        events.clearAll()

        engine?.detach()
        engine = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> {
                val apiKey = call.argument<String>("apiKey")
                val apiSecret = call.argument<String>("apiSecret")
                if (!apiKey.isNullOrEmpty() && !apiSecret.isNullOrEmpty()) {
                    engine?.initialize(apiKey, apiSecret)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGS", "apiKey or apiSecret is null/empty", null)
                }
            }
            "getTraceId" -> result.success(engine?.getTraceId())
            "lockIndoors" -> {
                (call.arguments as? List<*>)?.getOrNull(0)?.let { if (it is Boolean) engine?.lockIndoors(it) }
                result.success(null)
            }
            "lockFloor" -> {
                (call.arguments as? List<*>)?.getOrNull(0)?.let { if (it is Int) engine?.lockFloor(it) }
                result.success(null)
            }
            "unlockFloor" -> { engine?.unlockFloor(); result.success(null) }
            "startPositioning" -> { engine?.startPositioning(); result.success(null) }
            "stopPositioning" -> { engine?.stopPositioning(); result.success(null) }
            else -> result.notImplemented()
        }
    }

    // ---------
    // ActivityAware
    // ---------
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
}
