package com.indooratlas.flutter

import android.Manifest
import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import com.indooratlas.android.sdk.*

/**
 * IAFlutterPlugin — Plugin entrypoint
 *
 * - Exports a MethodChannel "com.indooratlas.flutter" for commands:
 *     initialize, startPositioning, stopPositioning, lockIndoors, lockFloor, unlockFloor, getTraceId
 *
 * - Exports EventChannels:
 *     com.indooratlas.flutter/events/status
 *     com.indooratlas.flutter/events/location
 *     com.indooratlas.flutter/events/region
 *     com.indooratlas.flutter/events/geofence
 *     com.indooratlas.flutter/events/orientation
 *     com.indooratlas.flutter/events/heading
 *
 * The plugin ensures all channel events are emitted on the main thread and tolerates null extras.
 */

private const val TAG = "IAFlutterPlugin"

class IAFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    // Method channel
    private lateinit var methodChannel: MethodChannel

    // Event channels and sinks
    private lateinit var statusChannel: EventChannel
    private lateinit var locationChannel: EventChannel
    private lateinit var regionChannel: EventChannel
    private lateinit var geofenceChannel: EventChannel
    private lateinit var orientationChannel: EventChannel
    private lateinit var headingChannel: EventChannel

    // Sinks (volatile to be safe)
    @Volatile private var statusSink: EventChannel.EventSink? = null
    @Volatile private var locationSink: EventChannel.EventSink? = null
    @Volatile private var regionSink: EventChannel.EventSink? = null
    @Volatile private var geofenceSink: EventChannel.EventSink? = null
    @Volatile private var orientationSink: EventChannel.EventSink? = null
    @Volatile private var headingSink: EventChannel.EventSink? = null

    private lateinit var engine: IAFlutterEngine

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "com.indooratlas.flutter")
        methodChannel.setMethodCallHandler(this)

        statusChannel = EventChannel(binding.binaryMessenger, "com.indooratlas.flutter/events/status")
        locationChannel = EventChannel(binding.binaryMessenger, "com.indooratlas.flutter/events/location")
        regionChannel = EventChannel(binding.binaryMessenger, "com.indooratlas.flutter/events/region")
        geofenceChannel = EventChannel(binding.binaryMessenger, "com.indooratlas.flutter/events/geofence")
        orientationChannel = EventChannel(binding.binaryMessenger, "com.indooratlas.flutter/events/orientation")
        headingChannel = EventChannel(binding.binaryMessenger, "com.indooratlas.flutter/events/heading")

        // Stream handlers that store sinks
        statusChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { statusSink = events }
            override fun onCancel(arguments: Any?) { statusSink = null }
        })
        locationChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { locationSink = events }
            override fun onCancel(arguments: Any?) { locationSink = null }
        })
        regionChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { regionSink = events }
            override fun onCancel(arguments: Any?) { regionSink = null }
        })
        geofenceChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { geofenceSink = events }
            override fun onCancel(arguments: Any?) { geofenceSink = null }
        })
        orientationChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { orientationSink = events }
            override fun onCancel(arguments: Any?) { orientationSink = null }
        })
        headingChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { headingSink = events }
            override fun onCancel(arguments: Any?) { headingSink = null }
        })

        engine = IAFlutterEngine(binding.applicationContext,
            statusSender = { m -> sendToSinkSafely(statusSink, m) },
            locationSender = { m -> sendToSinkSafely(locationSink, m) },
            regionSender = { m -> sendToSinkSafely(regionSink, m) },
            geofenceSender = { m -> sendToSinkSafely(geofenceSink, m) },
            orientationSender = { m -> sendToSinkSafely(orientationSink, m) },
            headingSender = { m -> sendToSinkSafely(headingSink, m) }
        )
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        statusChannel.setStreamHandler(null)
        locationChannel.setStreamHandler(null)
        regionChannel.setStreamHandler(null)
        geofenceChannel.setStreamHandler(null)
        orientationChannel.setStreamHandler(null)
        headingChannel.setStreamHandler(null)
        engine.detach()
    }

    private fun sendToSinkSafely(sink: EventChannel.EventSink?, map: Any) {
        try {
            // always post to main looper just in case
            Handler(Looper.getMainLooper()).post {
                try {
                    sink?.success(map)
                } catch (e: Exception) {
                    Log.w(TAG, "EventSink success failed: ${e.message}")
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "sendToSinkSafely post failed: ${e.message}")
        }
    }

    // MethodChannel handlers
    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                val apiKey = call.argument<String>("apiKey")
                val apiSecret = call.argument<String>("apiSecret")
                if (apiKey.isNullOrEmpty() || apiSecret.isNullOrEmpty()) {
                    result.error("INVALID_ARGS", "apiKey or apiSecret missing", null)
                } else {
                    engine.initialize(apiKey, apiSecret)
                    result.success(null)
                }
            }
            "startPositioning" -> {
                engine.startPositioning()
                result.success(null)
            }
            "stopPositioning" -> {
                engine.stopPositioning()
                result.success(null)
            }
            "lockIndoors" -> {
                val locked = (call.arguments as? List<*>)?.getOrNull(0) as? Boolean ?: true
                engine.lockIndoors(locked)
                result.success(null)
            }
            "lockFloor" -> {
                val floor = (call.arguments as? List<*>)?.getOrNull(0)
                if (floor is Int) engine.lockFloor(floor)
                result.success(null)
            }
            "unlockFloor" -> {
                engine.unlockFloor()
                result.success(null)
            }
            "getTraceId" -> {
                result.success(engine.getTraceId())
            }
            else -> result.notImplemented()
        }
    }

    // ActivityAware -- pass activity binding to engine so it can request permissions
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        engine.activityBinding = binding
    }
    override fun onDetachedFromActivityForConfigChanges() { engine.activityBinding = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { engine.activityBinding = binding }
    override fun onDetachedFromActivity() { engine.activityBinding = null }
}

// ---- IAFlutterEngine ----------------------------------------------------
class IAFlutterEngine(
    private val context: Context,
    private val statusSender: (Map<String, Any>) -> Unit,
    private val locationSender: (Map<String, Any>) -> Unit,
    private val regionSender: (Map<String, Any>) -> Unit,
    private val geofenceSender: (Map<String, Any>) -> Unit,
    private val orientationSender: (Map<String, Any>) -> Unit,
    private val headingSender: (Map<String, Any>) -> Unit
) : IALocationListener, IARegion.Listener, IAOrientationListener, IAGeofenceListener, PluginRegistry.RequestPermissionsResultListener {

    private val handler = Handler(Looper.getMainLooper())
    private var locationManager: IALocationManager? = null
    private var locationRequest: IALocationRequest = IALocationRequest.create()
    private var orientationRequest: IAOrientationRequest = IAOrientationRequest(1.0, 1.0)

    var activityBinding: PluginRegistry.ActivityResultListener? = null
        set(value) {
            // not used directly here — kept for API parity; RequestPermissionsResultListener is registered in setter below if needed
            field = value
        }

    private val PERMISSIONS = arrayOf(
        Manifest.permission.ACCESS_FINE_LOCATION,
        Manifest.permission.ACCESS_COARSE_LOCATION
    )

    private val PERMISSION_REQUEST_CODE = 444444

    // region: helpers for mapping to Dart-friendly maps
    private fun mapStatus(status: Int, message: String?): Map<String, Any> {
        val mapped = when (status) {
            IALocationManager.STATUS_OUT_OF_SERVICE -> 0
            IALocationManager.STATUS_TEMPORARILY_UNAVAILABLE -> 1
            IALocationManager.STATUS_AVAILABLE -> 2
            IALocationManager.STATUS_LIMITED -> 3
            else -> 0
        }
        return mapOf("status" to mapped, "message" to (message ?: ""))
    }

    private fun iaLocationToMap(loc: IALocation): Map<String, Any> {
        val m = mutableMapOf<String, Any>(
            "latitude" to loc.latitude,
            "longitude" to loc.longitude,
            "accuracy" to loc.accuracy,
            "altitude" to loc.altitude,
            "heading" to loc.bearing,
            "floorCertainty" to (loc.floorCertainty ?: 0.0),
            "flr" to (loc.floorLevel ?: 0),
            "velocity" to (loc.toLocation()?.speed ?: 0f),
            "timestamp" to loc.time
        )
        loc.region?.let { region ->
            m["region"] = mapOf(
                "regionId" to region.id,
                "timestamp" to region.timestamp,
                "regionType" to region.type,
                "floorPlan" to (region.floorPlan?.let { fp ->
                    mapOf(
                        "id" to fp.id,
                        "name" to fp.name,
                        "url" to fp.url,
                        "floorLevel" to fp.floorLevel,
                        "bitmapWidth" to fp.bitmapWidth,
                        "bitmapHeight" to fp.bitmapHeight,
                        "metersToPixels" to fp.metersToPixels,
                        "center" to listOf(fp.center.longitude, fp.center.latitude)
                    )
                }),
                "venue" to (region.venue?.let { v ->
                    mapOf("id" to v.id, "name" to v.name)
                })
            )
            region.floorPlan?.let { fp ->
                try {
                    val pt = fp.coordinateToPoint(loc.latLngFloor)
                    m["pix_x"] = pt.x
                    m["pix_y"] = pt.y
                } catch (e: Exception) {
                    // ignore
                }
            }
        }
        return m
    }
    // endregion

    // --- callbacks implemented by SDK ---
    override fun onStatusChanged(provider: String, status: Int, extras: Bundle?) {
        val message = extras?.getString("message") ?: ""
        handler.post {
            try {
                statusSender(mapStatus(status, message))
            } catch (e: Exception) {
                Log.w(TAG, "onStatusChanged send failed: ${e.message}")
            }
        }
    }

    override fun onLocationChanged(location: IALocation) {
        handler.post {
            try {
                locationSender(iaLocationToMap(location))
            } catch (e: Exception) {
                Log.w(TAG, "onLocationChanged send failed: ${e.message}")
            }
        }
    }

    override fun onEnterRegion(region: IARegion) {
        handler.post {
            try {
                regionSender(mapOf("enter" to true, "region" to mapOf(
                    "regionId" to region.id,
                    "timestamp" to region.timestamp,
                    "regionType" to region.type,
                    "floorPlan" to (region.floorPlan?.let { fp ->
                        mapOf(
                            "id" to fp.id,
                            "name" to fp.name,
                            "url" to fp.url,
                            "floorLevel" to fp.floorLevel
                        )
                    }),
                    "venue" to (region.venue?.let { v -> mapOf("id" to v.id, "name" to v.name) })
                )))
            } catch (e: Exception) {
                Log.w(TAG, "onEnterRegion send failed: ${e.message}")
            }
        }
    }

    override fun onExitRegion(region: IARegion) {
        handler.post {
            try {
                regionSender(mapOf("enter" to false, "region" to mapOf(
                    "regionId" to region.id,
                    "timestamp" to region.timestamp,
                    "regionType" to region.type
                )))
            } catch (e: Exception) {
                Log.w(TAG, "onExitRegion send failed: ${e.message}")
            }
        }
    }

    override fun onOrientationChange(timestamp: Long, quaternion: DoubleArray) {
        handler.post {
            try {
                orientationSender(mapOf(
                    "timestamp" to timestamp,
                    "x" to quaternion.getOrNull(0) ?: 0.0,
                    "y" to quaternion.getOrNull(1) ?: 0.0,
                    "z" to quaternion.getOrNull(2) ?: 0.0,
                    "w" to quaternion.getOrNull(3) ?: 0.0
                ))
            } catch (e: Exception) {
                Log.w(TAG, "onOrientationChange send failed: ${e.message}")
            }
        }
    }

    override fun onHeadingChanged(timestamp: Long, heading: Double) {
        handler.post {
            try {
                headingSender(mapOf("timestamp" to timestamp, "heading" to heading))
            } catch (e: Exception) {
                Log.w(TAG, "onHeadingChanged send failed: ${e.message}")
            }
        }
    }

    override fun onGeofencesTriggered(event: IAGeofenceEvent) {
        // Basic safe handling: iterate triggers and emit geofence events
        handler.post {
            try {
                event.triggers?.forEach { trigger ->
                    val type = if (trigger.transition == IAGeofence.GEOFENCE_TRANSITION_ENTER) "enter" else "exit"
                    val gf = trigger.geofence
                    gf?.let {
                        geofenceSender(mapOf("type" to type, "geofence" to mapOf(
                            "id" to it.id,
                            "name" to it.name,
                            "floor" to it.floor
                        )))
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "onGeofencesTriggered send failed: ${e.message}")
            }
        }
    }

    // Permissions result
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>?, grantResults: IntArray?): Boolean {
        return requestCode == PERMISSION_REQUEST_CODE
    }

    // Public API used by MethodChannel
    fun initialize(apiKey: String, apiSecret: String) {
        handler.post {
            try {
                val extras = Bundle().apply {
                    putString(IALocationManager.EXTRA_API_KEY, apiKey)
                    putString(IALocationManager.EXTRA_API_SECRET, apiSecret)
                }
                locationManager?.destroy()
                locationManager = IALocationManager.create(context, extras)
                // register region listener and geofence listener to receive callbacks
                locationManager?.registerRegionListener(this)
                locationManager?.registerGeofenceListener(this)
                locationManager?.registerOrientationListener(orientationRequest, this)
            } catch (e: Exception) {
                Log.e(TAG, "initialize failed: ${e.message}")
            }
        }
    }

    fun startPositioning() {
        handler.post {
            try {
                locationManager?.requestLocationUpdates(locationRequest, this)
            } catch (e: Exception) {
                Log.w(TAG, "startPositioning failed: ${e.message}")
            }
        }
    }

    fun stopPositioning() {
        handler.post {
            try {
                locationManager?.removeLocationUpdates(this)
            } catch (e: Exception) {
                Log.w(TAG, "stopPositioning failed: ${e.message}")
            }
        }
    }

    fun lockIndoors(locked: Boolean) {
        handler.post {
            try { locationManager?.lockIndoors(locked) } catch (_: Exception) {}
        }
    }

    fun lockFloor(floor: Int) {
        handler.post {
            try { locationManager?.lockFloor(floor) } catch (_: Exception) {}
        }
    }

    fun unlockFloor() {
        handler.post {
            try { locationManager?.unlockFloor() } catch (_: Exception) {}
        }
    }

    fun getTraceId(): String {
        return locationManager?.extraInfo?.traceId ?: ""
    }

    fun detach() {
        handler.post {
            try {
                locationManager?.destroy()
                locationManager = null
            } catch (e: Exception) {
                Log.w(TAG, "detach failed: ${e.message}")
            }
        }
    }
}
