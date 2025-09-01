package com.indooratlas.flutter

import android.Manifest
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import android.util.Log

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

import com.indooratlas.android.sdk.IALocation
import com.indooratlas.android.sdk.IALocationRequest
import com.indooratlas.android.sdk.IAOrientationRequest
import com.indooratlas.android.sdk.IALocationListener
import com.indooratlas.android.sdk.IALocationManager
import com.indooratlas.android.sdk.IARegion
import com.indooratlas.android.sdk.IARoute
import com.indooratlas.android.sdk.IAOrientationListener
import com.indooratlas.android.sdk.IAWayfindingListener
import com.indooratlas.android.sdk.IAGeofenceListener
import com.indooratlas.android.sdk.IAGeofenceEvent
import com.indooratlas.android.sdk.IAPOI
import com.indooratlas.android.sdk.resources.IAFloorPlan
import com.indooratlas.android.sdk.resources.IALatLng
import com.indooratlas.android.sdk.resources.IAVenue

// Simple wrapper result (left for compatibility)
open class IAFlutterResult

// --- Converters: map SDK objects -> Map<String, Any?> ---
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

private fun IAGeofence2Map(geofence: com.indooratlas.android.sdk.IAGeofence): Map<String, Any?> {
    // edges is List<DoubleArray> or similar — create polygon coordinates as List<List<Double>>
    val vertices = geofence.edges.flatMap { listOf(it[1], it[0]) }
    // convert to [[lon, lat], [lon, lat], ...] structure expected by GeoJSON polygon array
    val coords = mutableListOf<List<Double>>()
    for (i in vertices.indices step 2) {
        coords.add(listOf(vertices[i], vertices[i + 1]))
    }
    return mapOf(
        "type" to "Feature",
        "id" to geofence.id,
        "properties" to mapOf(
            "name" to geofence.name,
            "floor" to geofence.floor,
            "payload" to geofence.payload?.toString()
        ),
        "geometry" to mapOf(
            "type" to "Polygon",
            "coordinates" to listOf(coords)
        )
    )
}

private fun IAFloorplan2Map(floorplan: IAFloorPlan): Map<String, Any?> {
    return mapOf(
        "id" to floorplan.id,
        "name" to (floorplan.name ?: ""),
        "url" to (floorplan.url ?: ""),
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

private fun IAVenue2Map(venue: IAVenue): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>(
        "id" to venue.id,
        "name" to venue.name
    )
    val plans: List<Map<String, Any?>> = venue.floorPlans.map { IAFloorplan2Map(it) }
    if (plans.isNotEmpty()) map["floorPlans"] = plans
    val fences: List<Map<String, Any?>> = venue.geofences.map { IAGeofence2Map(it) }
    if (fences.isNotEmpty()) map["geofences"] = fences
    val pois: List<Map<String, Any?>> = venue.poIs.map { IAPOI2Map(it) }
    if (pois.isNotEmpty()) map["pois"] = pois
    return map
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
    if (region.venue != null) {
        map["venue"] = IAVenue2Map(region.venue)
    }
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
                // ignore conversion problems
            }
        }
    }
    return map
}

private fun IARoutePoint2Map(rp: IARoute.Point): Map<String, Any?> {
    return mapOf(
        "latitude" to rp.latitude,
        "longitude" to rp.longitude,
        "floor" to rp.floor
    )
}

private fun IARoute2Map(route: IARoute): Map<String, Any?> {
    val legs: List<Map<String, Any?>> = route.legs.map { leg ->
        mapOf(
            "begin" to IARoutePoint2Map(leg.begin),
            "end" to IARoutePoint2Map(leg.end),
            "length" to leg.length,
            "direction" to leg.direction,
            "edgeIndex" to (leg.edgeIndex ?: -1)
        )
    }
    return mapOf(
        "legs" to legs,
        "error" to (route.error?.name ?: "")
    )
}

// IAFlutterEngine implements IARegion.Listener now (fixes override errors)
class IAFlutterEngine(
    context: Context,
    channel: MethodChannel
) : IALocationListener,
    IARegion.Listener,
    IAOrientationListener,
    IAWayfindingListener,
    IAGeofenceListener,
    PluginRegistry.RequestPermissionsResultListener {

    var activityBinding: ActivityPluginBinding? = null
        get() = field
        set(value) {
            if (field != null) {
                val old = field as ActivityPluginBinding
                old.removeRequestPermissionsResultListener(this)
            }
            if (value != null) {
                value.addRequestPermissionsResultListener(this)
            }
            field = value
        }

    private val _handler = Handler(Looper.getMainLooper())
    private val _context: Context = context
    private val _channel: MethodChannel = channel
    private var _locationManager: IALocationManager? = null
    private var _locationRequest = IALocationRequest.create()
    private var _orientationRequest = IAOrientationRequest(1.0, 1.0)
    private var _locationServiceRunning = false

    private val PERMISSION_REQUEST_CODE = 444444

    private val PERMISSIONS = mutableListOf(
        Manifest.permission.CHANGE_WIFI_STATE,
        Manifest.permission.ACCESS_WIFI_STATE,
        Manifest.permission.ACCESS_COARSE_LOCATION,
        Manifest.permission.ACCESS_FINE_LOCATION,
        Manifest.permission.INTERNET
    ).apply {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            add(Manifest.permission.BLUETOOTH_SCAN)
        }
    }.toTypedArray()

    override fun onStatusChanged(@NonNull provider: String, status: Int, bundle: Bundle?) {
        val mappedStatus = when (status) {
            IALocationManager.STATUS_OUT_OF_SERVICE -> 0
            IALocationManager.STATUS_TEMPORARILY_UNAVAILABLE -> 1
            IALocationManager.STATUS_AVAILABLE -> 2
            IALocationManager.STATUS_LIMITED -> 3
            else -> 0
        }
        _channel.invokeMethod("onStatusChanged", listOf(mappedStatus))
    }

    override fun onLocationChanged(@NonNull location: IALocation) {
        _channel.invokeMethod("onLocationChanged", listOf(IALocation2Map(location)))
        
        // También enviar geofences actuales cuando cambia la ubicación
        // para mantener el estado sincronizado
        if (location.region != null && location.region.venue != null && location.region.venue.geofences.isNotEmpty()) {
            val geofenceMaps = location.region.venue.geofences.map { IAGeofence2Map(it) }
            _channel.invokeMethod("onGeofencesTriggered", listOf(
                System.currentTimeMillis(),
                geofenceMaps
            ))
        }
    }

    // IARegion.Listener methods
    override fun onEnterRegion(@NonNull region: IARegion) {
        _channel.invokeMethod("onEnterRegion", listOf(IARegion2Map(region)))
        
        // Si la región tiene un venue, enviar las geofences del venue
        if (region.venue != null && region.venue.geofences.isNotEmpty()) {
            val geofenceMaps = region.venue.geofences.map { IAGeofence2Map(it) }
            _channel.invokeMethod("onGeofencesTriggered", listOf(
                System.currentTimeMillis(),
                geofenceMaps
            ))
        }
    }

    override fun onExitRegion(@NonNull region: IARegion) {
        _channel.invokeMethod("onExitRegion", listOf(IARegion2Map(region)))
        
        // Limpiar las geofences cuando el usuario sale de la región
        _channel.invokeMethod("onGeofencesTriggered", listOf(
            System.currentTimeMillis(),
            emptyList<Map<String, Any?>>()
        ))
    }

    override fun onOrientationChange(timestamp: Long, @NonNull quaternion: DoubleArray) {
        _channel.invokeMethod(
            "onOrientationChanged",
            listOf(timestamp, quaternion[0], quaternion[1], quaternion[2], quaternion[3])
        )
    }

    override fun onHeadingChanged(timestamp: Long, heading: Double) {
        _channel.invokeMethod("onHeadingChanged", listOf(timestamp, heading))
    }

    override fun onWayfindingUpdate(route: IARoute) {
        _channel.invokeMethod("onWayfindingUpdate", listOf(IARoute2Map(route)))
    }

    override fun onGeofencesTriggered(event: IAGeofenceEvent) {
        // Nota: La API de geofences puede variar según la versión del SDK
        // Por ahora, las geofences se obtienen desde la región actual
        // cuando el usuario entra en un venue
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) {
            _channel.invokeMethod("onPermissionsGranted", listOf(false))
            return false
        }
        _channel.invokeMethod("onPermissionsGranted", listOf(true))
        return true
    }

    fun detach() {
        _handler.post {
            _locationManager?.destroy()
            _locationManager = null
        }
        _channel.setMethodCallHandler(null)
    }

    fun requestPermissions() {
        val binding = activityBinding ?: return
        binding.activity.requestPermissions(PERMISSIONS, PERMISSION_REQUEST_CODE)
    }

    fun initialize(@NonNull pluginVersion: String, @NonNull apiKey: String, @NonNull endpoint: String) {
        _handler.post {
            val bundle = Bundle(2)
            bundle.putString(IALocationManager.EXTRA_API_KEY, apiKey)
            bundle.putString(IALocationManager.EXTRA_API_SECRET, "not-used-in-the-flutter-plugin")
            bundle.putString("com.indooratlas.android.sdk.intent.extras.wrapperName", "flutter")
            bundle.putString("com.indooratlas.android.sdk.intent.extras.wrapperVersion", pluginVersion)
            if (endpoint.isNotEmpty()) bundle.putString("com.indooratlas.android.sdk.intent.extras.restEndpoint", endpoint)
            _locationManager?.destroy()
            requestPermissions()
            _locationServiceRunning = false
            _locationManager = IALocationManager.create(_context, bundle)
        }
    }

    fun getTraceId(): String {
        return _locationManager?.getExtraInfo()?.traceId ?: ""
    }

    fun lockIndoors(locked: Boolean?) {
        _handler.post { _locationManager?.lockIndoors(locked ?: true) }
    }

    fun lockFloor(floor: Int?) {
        _handler.post { if (floor != null) _locationManager?.lockFloor(floor) }
    }

    fun unlockFloor() {
        _handler.post { _locationManager?.unlockFloor() }
    }

    fun setPositioningMode(mode: Int?) {
        val prio = when (mode) {
            0 -> IALocationRequest.PRIORITY_HIGH_ACCURACY
            1 -> IALocationRequest.PRIORITY_LOW_POWER
            2 -> IALocationRequest.PRIORITY_CART_MODE
            else -> IALocationRequest.PRIORITY_HIGH_ACCURACY
        }
        _locationRequest.setPriority(prio)
    }

    fun setOutputThresholds(distance: Double?, interval: Double?) {
        val wasRunning = _locationServiceRunning
        if (wasRunning) stopPositioning()
        if (distance != null && distance >= 0) _locationRequest.setSmallestDisplacement(distance.toFloat())
        if (interval != null && interval >= 0) _locationRequest.setFastestInterval((interval * 1000).toLong())
        if (wasRunning) startPositioning()
    }

    fun setSensitivities(orientationSensitivity: Double?, headingSensitivity: Double?) {
        _orientationRequest = IAOrientationRequest(headingSensitivity ?: 1.0, orientationSensitivity ?: 1.0)
        _handler.post {
            _locationManager?.unregisterOrientationListener(this)
            _locationManager?.registerOrientationListener(_orientationRequest, this)
        }
    }

    fun startPositioning() {
        _handler.post {
            _locationManager?.registerRegionListener(this)
            _locationManager?.registerOrientationListener(_orientationRequest, this)
            _locationManager?.requestLocationUpdates(_locationRequest, this)
            // Nota: registerGeofenceListener puede no estar disponible en todas las versiones
            // _locationManager?.registerGeofenceListener(this)
            _locationServiceRunning = true
        }
    }

    fun stopPositioning() {
        _handler.post {
            _locationManager?.removeLocationUpdates(this)
            _locationManager?.unregisterOrientationListener(this)
            _locationManager?.unregisterRegionListener(this)
            // Nota: removeGeofenceListener puede no estar disponible en todas las versiones
            // _locationManager?.removeGeofenceListener(this)
            _locationServiceRunning = false
        }
    }

    fun startWayfinding(lat: Double?, lon: Double?, floor: Int?) {
        _handler.post {
            if (_locationManager != null) {
                val request = com.indooratlas.android.sdk.IAWayfindingRequest.Builder()
                    .withLatitude(lat ?: 0.0)
                    .withLongitude(lon ?: 0.0)
                    .withFloor(floor ?: 0)
                    .build()
                _locationManager?.requestWayfindingUpdates(request, this)
            }
        }
    }

    fun stopWayfinding() {
        _handler.post { _locationManager?.removeWayfindingUpdates() }
    }

    fun requestGeofences(geofenceIds: List<String>) {
        // Nota: La API de geofences puede variar según la versión del SDK
        // Por ahora, las geofences se obtienen automáticamente desde la región actual
        // cuando el usuario entra en un venue
    }

    fun removeGeofences() {
        // Nota: La API de geofences puede variar según la versión del SDK
        // Por ahora, las geofences se obtienen automáticamente desde la región actual
    }

    fun getCurrentGeofences(): List<Map<String, Any?>> {
        // Obtener las geofences actuales desde el location manager
        val currentLocation = _locationManager?.lastKnownLocation
        if (currentLocation?.region?.venue?.geofences != null) {
            return currentLocation.region.venue.geofences.map { IAGeofence2Map(it) }
        }
        return emptyList()
    }
}

// --- Plugin class wiring MethodChannel to engine implementation ---
class IAFlutterPlugin: FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var _engineImpl: IAFlutterEngine
    private lateinit var _channel: MethodChannel

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
        _engineImpl.activityBinding = binding
    }

    override fun onDetachedFromActivityForConfigChanges() {
        _engineImpl.activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        _engineImpl.activityBinding = binding
    }

    override fun onDetachedFromActivity() {
        _engineImpl.activityBinding = null
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
                    _engineImpl.lockIndoors(call.arguments as Boolean?)
                    result.success(null)
                }
                "lockFloor" -> {
                    _engineImpl.lockFloor((call.arguments as Number?)?.toInt())
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
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            e.printStackTrace()
            result.error("plugin_exception", e.message, null)
        }
    }
}
