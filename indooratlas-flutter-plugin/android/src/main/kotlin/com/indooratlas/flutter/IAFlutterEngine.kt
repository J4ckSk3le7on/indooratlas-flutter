package com.indooratlas.flutter

// Android imports
import android.Manifest
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull

// Flutter / plugin imports
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

// IndoorAtlas imports
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

// Simple wrapper result (left for compatibility)
open class IAFlutterResult

// ---------- Mapping helpers ----------
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
    val vertices = geofence.edges.flatMap { listOf(it[1], it[0]) }
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

// ---------- Engine ----------
class IAFlutterEngine(
    context: Context,
    private val _channel: MethodChannel
) : IALocationListener,
    IARegion.Listener,
    IAOrientationListener,
    IAGeofenceListener,
    PluginRegistry.RequestPermissionsResultListener {

    // activity binding (set from plugin)
    var activityBinding: ActivityPluginBinding? = null
        set(value) {
            field?.removeRequestPermissionsResultListener(this)
            value?.addRequestPermissionsResultListener(this)
            field = value
        }

    private val _handler = Handler(Looper.getMainLooper())
    private val _context: Context = context

    // internal state
    private var _locationManager: IALocationManager? = null
    private var _locationRequest = IALocationRequest.create()
    private var _orientationRequest = IAOrientationRequest(1.0, 1.0)
    private var _locationServiceRunning = false
    private var _currentLocation: IALocation? = null
    private val _currentGeofences = mutableListOf<Map<String, Any?>>()
    private val _currentTriggeredGeofenceIds = mutableSetOf<String>()

    // wayfinding storage (listener or pendingintent path)
    private var _currentWayfindingListener: com.indooratlas.android.sdk.IAWayfindingListener? = null
    private var _wayfindingPendingIntent: PendingIntent? = null
    private var _wayfindingReceiver: BroadcastReceiver? = null

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

    // -------- IALocationListener --------
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
        _currentLocation = location
        _channel.invokeMethod("onLocationChanged", listOf(IALocation2Map(location)))

        if (location.region != null && location.region.venue != null && location.region.venue.geofences.isNotEmpty()) {
            val geofenceMaps = location.region.venue.geofences.map { IAGeofence2Map(it) }
            _currentGeofences.clear()
            _currentGeofences.addAll(geofenceMaps)
            _channel.invokeMethod("onGeofencesTriggered", listOf(
                System.currentTimeMillis(),
                geofenceMaps
            ))

            _checkGeofenceTriggers(location, location.region.venue.geofences)
        }
    }

    private fun _checkGeofenceTriggers(location: IALocation, geofences: List<com.indooratlas.android.sdk.IAGeofence>) {
        val currentTriggeredIds = mutableSetOf<String>()

        for (geofence in geofences) {
            if (_isLocationInGeofence(location, geofence)) {
                currentTriggeredIds.add(geofence.id)
            }
        }

        val previousTriggeredIds = _currentTriggeredGeofenceIds.toSet()

        for (geofenceId in currentTriggeredIds) {
            if (!previousTriggeredIds.contains(geofenceId)) {
                _channel.invokeMethod("onGeofenceEvent", listOf(geofenceId, "ENTER"))
            }
        }

        for (geofenceId in previousTriggeredIds) {
            if (!currentTriggeredIds.contains(geofenceId)) {
                _channel.invokeMethod("onGeofenceEvent", listOf(geofenceId, "EXIT"))
            }
        }

        _currentTriggeredGeofenceIds.clear()
        _currentTriggeredGeofenceIds.addAll(currentTriggeredIds)
    }

    private fun _isLocationInGeofence(location: IALocation, geofence: com.indooratlas.android.sdk.IAGeofence): Boolean {
        if (geofence.edges.isEmpty()) return false

        val point = doubleArrayOf(location.longitude, location.latitude)
        val polygon = geofence.edges.map { it.reversedArray() }
        return _isPointInPolygon(point, polygon)
    }

    private fun _isPointInPolygon(point: DoubleArray, polygon: List<DoubleArray>): Boolean {
        if (polygon.size < 3) return false

        var inside = false
        var j = polygon.size - 1

        for (i in polygon.indices) {
            val edge = polygon[i]
            val prevEdge = polygon[j]

            if (((edge[1] > point[1]) != (prevEdge[1] > point[1])) &&
                (point[0] < (prevEdge[0] - edge[0]) * (point[1] - edge[1]) /
                        (prevEdge[1] - edge[1]) + edge[0])) {
                inside = !inside
            }
            j = i
        }

        return inside
    }

    // IARegion.Listener methods
    override fun onEnterRegion(@NonNull region: IARegion) {
        _channel.invokeMethod("onEnterRegion", listOf(IARegion2Map(region)))

        if (region.venue != null && region.venue.geofences.isNotEmpty()) {
            val geofenceMaps = region.venue.geofences.map { IAGeofence2Map(it) }
            _currentGeofences.clear()
            _currentGeofences.addAll(geofenceMaps)
            _channel.invokeMethod("onGeofencesTriggered", listOf(
                System.currentTimeMillis(),
                geofenceMaps
            ))

            if (_currentLocation != null) {
                _checkGeofenceTriggers(_currentLocation!!, region.venue.geofences)
            }
        }
    }

    override fun onExitRegion(@NonNull region: IARegion) {
        _channel.invokeMethod("onExitRegion", listOf(IARegion2Map(region)))

        _currentGeofences.clear()
        _channel.invokeMethod("onGeofencesTriggered", listOf(
            System.currentTimeMillis(),
            emptyList<Map<String, Any?>>()
        ))

        for (geofenceId in _currentTriggeredGeofenceIds) {
            _channel.invokeMethod("onGeofenceEvent", listOf(geofenceId, "EXIT"))
        }
        _currentTriggeredGeofenceIds.clear()
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

    override fun onGeofencesTriggered(event: IAGeofenceEvent) {
        // no-op here, we handle geofences via regions/venue
    }

    // RequestPermissionsResultListener callback implementation
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
            // cleanup wayfinding receiver if any
            _wayfindingReceiver?.let {
                try { _context.unregisterReceiver(it) } catch (_: Exception) {}
                _wayfindingReceiver = null
            }
            _wayfindingPendingIntent = null
            _currentWayfindingListener = null
        }
        _channel.setMethodCallHandler(null)
    }

    fun requestPermissions() {
        val binding = activityBinding ?: return
        // use ActivityPluginBinding to request permissions
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

    fun lockIndoors(locked: Boolean) {
        _handler.post { _locationManager?.lockIndoors(locked) }
    }

    fun lockFloor(floor: Int) {
        _handler.post { _locationManager?.lockFloor(floor) }
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
        _orientationRequest = IAOrientationRequest(headingSensitivity ?: 5.0, orientationSensitivity ?: 5.0)
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
            _locationServiceRunning = true
        }
    }

    fun stopPositioning() {
        _handler.post {
            _locationManager?.removeLocationUpdates(this)
            _locationManager?.unregisterOrientationListener(this)
            _locationManager?.unregisterRegionListener(this)
            _locationServiceRunning = false
        }
    }

    /**
     * startWayfinding: compatible con SDKs que aceptan IAWayfindingListener y con SDKs que
     * usan PendingIntent (broadcast). Primero intenta la variante con listener por reflexión;
     * si no está disponible, crea un PendingIntent y registra un BroadcastReceiver para recibir
     * actualizaciones.
     */
    fun startWayfinding(lat: Double?, lon: Double?, floor: Int?, mode: Int? = null) {
        _handler.post {
            val mgr = _locationManager ?: return@post
            val builder = com.indooratlas.android.sdk.IAWayfindingRequest.Builder()
                .withLatitude(lat ?: 0.0)
                .withLongitude(lon ?: 0.0)
                .withFloor(floor ?: 0)
            if (mode != null) {
                try {
                    when (mode) {
                        1 -> builder.withTags(com.indooratlas.android.sdk.IAWayfindingTags.EXCLUDE_INACCESSIBLE)
                        2 -> builder.withTags(com.indooratlas.android.sdk.IAWayfindingTags.EXCLUDE_ACCESSIBLE_ONLY)
                    }
                } catch (e: Exception) {
                    // tags might not exist on every SDK version
                }
            }
            val request = builder.build()

            // remove previous wayfinding registrations safely
            try {
                // try listener-based removal first
                val rmListener = mgr.javaClass.methods.firstOrNull { it.name == "removeWayfindingUpdates" && it.parameterTypes.size == 1 && it.parameterTypes[0].name.contains("IAWayfindingListener") }
                if (rmListener != null && _currentWayfindingListener != null) {
                    rmListener.invoke(mgr, _currentWayfindingListener)
                } else {
                    // try pendingintent removal
                    val rmPI = mgr.javaClass.methods.firstOrNull { it.name == "removeWayfindingUpdates" && it.parameterTypes.size == 1 && android.app.PendingIntent::class.java.isAssignableFrom(it.parameterTypes[0]) }
                    rmPI?.let {
                        _wayfindingPendingIntent?.let { pi ->
                            try {
                                it.invoke(mgr, pi)
                            } catch (_: Exception) {}
                        }
                    }
                }
            } catch (e: Exception) {
                Log.w("IAFlutterEngine", "Failed to remove previous wayfinding registration", e)
            }

            // prepare listener (for listener-based API)
            val listener = object : com.indooratlas.android.sdk.IAWayfindingListener {
                override fun onWayfindingUpdate(route: com.indooratlas.android.sdk.IARoute) {
                    try {
                        _channel.invokeMethod("onWayfindingUpdate", listOf(IARoute2Map(route)))
                    } catch (e: Exception) {
                        Log.e("IAFlutterEngine", "Error invoking onWayfindingUpdate", e)
                    }
                }
            }

            _currentWayfindingListener = listener

            // ------------------------------------------------------------
            // Fast-path for latest SDK versions (>= 3.0): call directly
            // ------------------------------------------------------------
            try {
                mgr.requestWayfindingUpdates(request, listener)
                return@post
            } catch (e: NoSuchMethodError) {
                // ignore – older SDK; fall back below
            } catch (e: Throwable) {
                Log.w("IAFlutterEngine", "Direct requestWayfindingUpdates failed; trying reflection", e)
            }

            // 1) Try direct listener-based method by reflection
            val methodWithListener = mgr.javaClass.methods.firstOrNull {
                it.name == "requestWayfindingUpdates" &&
                        it.parameterTypes.size == 2 &&
                        it.parameterTypes[0].name.contains("IAWayfindingRequest") &&
                        it.parameterTypes[1].name.contains("IAWayfindingListener")
            }
            if (methodWithListener != null) {
                try {
                    methodWithListener.invoke(mgr, request, listener)
                    return@post
                } catch (e: Exception) {
                    Log.w("IAFlutterEngine", "Listener-based requestWayfindingUpdates reflection failed", e)
                    // fall through to try PendingIntent approach
                }
            }

            // 2) Try PendingIntent-based API: construct PendingIntent + BroadcastReceiver and call method
            val methodWithPI = mgr.javaClass.methods.firstOrNull {
                it.name == "requestWayfindingUpdates" &&
                        it.parameterTypes.size == 2 &&
                        it.parameterTypes[0].name.contains("IAWayfindingRequest") &&
                        android.app.PendingIntent::class.java.isAssignableFrom(it.parameterTypes[1])
            }

            if (methodWithPI != null) {
                try {
                    // Prepare action and PendingIntent
                    val action = "com.indooratlas.flutter.WAYFINDING_UPDATE"
                    val intent = Intent(action)
                    // target only our app
                    intent.setPackage(_context.packageName)

                    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }

                    val pi = PendingIntent.getBroadcast(_context, System.identityHashCode(request), intent, flags)
                    _wayfindingPendingIntent = pi

                    // register receiver
                    _wayfindingReceiver?.let {
                        try { _context.unregisterReceiver(it) } catch (_: Exception) {}
                        _wayfindingReceiver = null
                    }
                    _wayfindingReceiver = object : BroadcastReceiver() {
                        override fun onReceive(ctx: Context?, intent: Intent?) {
                            try {
                                if (intent == null) return
                                // Attempt 1: SDK might put an IARoute as a Parcelable under "route"
                                val parcelRoute = intent.getParcelableExtra<com.indooratlas.android.sdk.IARoute>("route")
                                if (parcelRoute != null) {
                                    _channel.invokeMethod("onWayfindingUpdate", listOf(IARoute2Map(parcelRoute)))
                                    return
                                }
                                // Attempt 2: check extras for any IARoute or serializable object
                                val extras = intent.extras
                                if (extras != null) {
                                    for (key in extras.keySet()) {
                                        val extra = extras.get(key)
                                        if (extra is com.indooratlas.android.sdk.IARoute) {
                                            _channel.invokeMethod("onWayfindingUpdate", listOf(IARoute2Map(extra)))
                                            return
                                        }
                                    }
                                }
                                // If nothing understood, log contents for debug
                                Log.d("IAFlutterEngine", "Wayfinding broadcast received but no route found; extras=${intent.extras?.keySet()}")
                            } catch (e: Exception) {
                                Log.e("IAFlutterEngine", "Wayfinding receiver error", e)
                            }
                        }
                    }
                    _context.registerReceiver(_wayfindingReceiver, IntentFilter(action))

                    // invoke SDK method
                    methodWithPI.invoke(mgr, request, pi)
                    return@post
                } catch (e: Exception) {
                    Log.e("IAFlutterEngine", "PendingIntent-based requestWayfindingUpdates failed", e)
                }
            }

            // If neither method present, log error
            Log.e("IAFlutterEngine", "No compatible requestWayfindingUpdates overload found on IALocationManager")
        }
    }

    /**
     * stopWayfinding: también soporta ambas variantes por reflexión.
     */
    fun stopWayfinding() {
        _handler.post {
            val mgr = _locationManager ?: return@post

            // Fast-path: try direct public API first
            try {
                _currentWayfindingListener?.let {
                    mgr.removeWayfindingUpdates(it)
                    _currentWayfindingListener = null
                    return@post
                }
            } catch (e: NoSuchMethodError) {
                // fall through to reflection variations below
            } catch (e: Throwable) {
                Log.w("IAFlutterEngine", "Direct removeWayfindingUpdates failed; falling back", e)
            }

            // Try listener-based remove
            val rmListener = mgr.javaClass.methods.firstOrNull { it.name == "removeWayfindingUpdates" && it.parameterTypes.size == 1 && it.parameterTypes[0].name.contains("IAWayfindingListener") }
            if (rmListener != null && _currentWayfindingListener != null) {
                try { rmListener.invoke(mgr, _currentWayfindingListener) } catch (e: Exception) { Log.w("IAFlutterEngine", "removeWayfindingUpdates(listener) failed", e) }
                _currentWayfindingListener = null
                return@post
            }

            // Try PendingIntent remove
            val rmPI = mgr.javaClass.methods.firstOrNull { it.name == "removeWayfindingUpdates" && it.parameterTypes.size == 1 && android.app.PendingIntent::class.java.isAssignableFrom(it.parameterTypes[0]) }
            if (rmPI != null) {
                try {
                    _wayfindingPendingIntent?.let { pi ->
                        rmPI.invoke(mgr, pi)
                    }
                } catch (e: Exception) {
                    Log.w("IAFlutterEngine", "removeWayfindingUpdates(pendingIntent) failed", e)
                } finally {
                    // cleanup receiver and pi
                    _wayfindingReceiver?.let {
                        try { _context.unregisterReceiver(it) } catch (_: Exception) {}
                        _wayfindingReceiver = null
                    }
                    _wayfindingPendingIntent = null
                }
                return@post
            }

            // No supported removal method found, log and clear stored listener
            Log.w("IAFlutterEngine", "No compatible removeWayfindingUpdates overload found on IALocationManager")
            _currentWayfindingListener = null
            _wayfindingPendingIntent = null
            _wayfindingReceiver?.let {
                try { _context.unregisterReceiver(it) } catch (_: Exception) {}
                _wayfindingReceiver = null
            }
        }
    }

    fun requestGeofences(geofenceIds: List<String>) {
        // placeholder (implement per SDK version if needed)
    }

    fun removeGeofences() {
        // placeholder
    }

    fun getCurrentGeofences(): List<Map<String, Any?>> {
        return _currentGeofences.toList()
    }
}
