package com.indooratlas.flutter

import android.Manifest
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat

// Flutter / plugin imports
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

// IndoorAtlas SDK imports
import com.indooratlas.android.sdk.*
import com.indooratlas.android.sdk.resources.*

/**
 * Main engine for IndoorAtlas Flutter plugin
 * Handles all IndoorAtlas SDK interactions and bridges them to Flutter
 */
class IAFlutterEngine(
    private val context: Context,
    private val channel: MethodChannel
) : IALocationListener,
    IARegion.Listener,
    IAOrientationListener,
    IAGeofenceListener,
    PluginRegistry.RequestPermissionsResultListener {

    companion object {
        private const val TAG = "IAFlutterEngine"
        private const val PERMISSION_REQUEST_CODE = 444444
        private const val WAYFINDING_ACTION = "com.indooratlas.flutter.WAYFINDING_UPDATE"
        
        // Required permissions for IndoorAtlas
        private val REQUIRED_PERMISSIONS = buildList {
            add(Manifest.permission.CHANGE_WIFI_STATE)
            add(Manifest.permission.ACCESS_WIFI_STATE)
            add(Manifest.permission.ACCESS_COARSE_LOCATION)
            add(Manifest.permission.ACCESS_FINE_LOCATION)
            add(Manifest.permission.INTERNET)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                add(Manifest.permission.BLUETOOTH_SCAN)
                add(Manifest.permission.BLUETOOTH_CONNECT)
            }
        }.toTypedArray()
    }

    // Activity binding for permission requests
    var activityBinding: ActivityPluginBinding? = null
        set(value) {
            field?.removeRequestPermissionsResultListener(this)
            value?.addRequestPermissionsResultListener(this)
            field = value
        }

    // IndoorAtlas SDK components
    private var locationManager: IALocationManager? = null
    private var locationRequest = IALocationRequest.create()
    private var orientationRequest = IAOrientationRequest(5.0, 5.0)
    
    // State tracking
    private var isLocationServiceRunning = false
    private var currentLocation: IALocation? = null
    private val currentGeofences = mutableListOf<Map<String, Any?>>()
    private val triggeredGeofenceIds = mutableSetOf<String>()
    
    // Wayfinding components
    private var wayfindingListener: IAWayfindingListener? = null
    private var wayfindingPendingIntent: PendingIntent? = null
    private var wayfindingReceiver: BroadcastReceiver? = null
    
    // Threading
    private val mainHandler = Handler(Looper.getMainLooper())

    // -------- IALocationListener Implementation --------
    
    override fun onStatusChanged(@NonNull provider: String, status: Int, bundle: Bundle?) {
        val mappedStatus = when (status) {
            IALocationManager.STATUS_OUT_OF_SERVICE -> 0
            IALocationManager.STATUS_TEMPORARILY_UNAVAILABLE -> 1
            IALocationManager.STATUS_AVAILABLE -> 2
            IALocationManager.STATUS_LIMITED -> 3
            else -> 0
        }
        
        mainHandler.post {
            channel.invokeMethod("onStatusChanged", listOf(mappedStatus))
        }
    }

    override fun onLocationChanged(@NonNull location: IALocation) {
        currentLocation = location
        
        mainHandler.post {
            channel.invokeMethod("onLocationChanged", listOf(location.toMap()))
        }

        // Handle geofences if available
        location.region?.venue?.let { venue ->
            if (venue.geofences.isNotEmpty()) {
                val geofenceMaps = venue.geofences.map { it.toMap() }
                currentGeofences.clear()
                currentGeofences.addAll(geofenceMaps)
                
                mainHandler.post {
                    channel.invokeMethod("onGeofencesTriggered", listOf(
                        System.currentTimeMillis(),
                        geofenceMaps
                    ))
                }
                
                checkGeofenceTriggers(location, venue.geofences)
            }
        }
    }

    // -------- IARegion.Listener Implementation --------
    
    override fun onEnterRegion(@NonNull region: IARegion) {
        mainHandler.post {
            channel.invokeMethod("onEnterRegion", listOf(region.toMap()))
        }

        // Handle venue geofences
        region.venue?.let { venue ->
            if (venue.geofences.isNotEmpty()) {
                val geofenceMaps = venue.geofences.map { it.toMap() }
                currentGeofences.clear()
                currentGeofences.addAll(geofenceMaps)
                
                mainHandler.post {
                    channel.invokeMethod("onGeofencesTriggered", listOf(
                        System.currentTimeMillis(),
                        geofenceMaps
                    ))
                }
                
                currentLocation?.let { location ->
                    checkGeofenceTriggers(location, venue.geofences)
                }
            }
        }
    }

    override fun onExitRegion(@NonNull region: IARegion) {
        mainHandler.post {
            channel.invokeMethod("onExitRegion", listOf(region.toMap()))
        }

        // Clear geofences and trigger exit events
        currentGeofences.clear()
        mainHandler.post {
            channel.invokeMethod("onGeofencesTriggered", listOf(
                System.currentTimeMillis(),
                emptyList<Map<String, Any?>>()
            ))
        }

        // Send exit events for all previously triggered geofences
        for (geofenceId in triggeredGeofenceIds) {
            mainHandler.post {
                channel.invokeMethod("onGeofenceEvent", listOf(geofenceId, "EXIT"))
            }
        }
        triggeredGeofenceIds.clear()
    }

    // -------- IAOrientationListener Implementation --------
    
    override fun onOrientationChange(timestamp: Long, @NonNull quaternion: DoubleArray) {
        if (quaternion.size >= 4) {
            mainHandler.post {
                channel.invokeMethod("onOrientationChanged", listOf(
                    timestamp, quaternion[0], quaternion[1], quaternion[2], quaternion[3]
                ))
            }
        }
    }

    override fun onHeadingChanged(timestamp: Long, heading: Double) {
        mainHandler.post {
            channel.invokeMethod("onHeadingChanged", listOf(timestamp, heading))
        }
    }

    // -------- IAGeofenceListener Implementation --------
    
    override fun onGeofencesTriggered(event: IAGeofenceEvent) {
        // This is handled via venue geofences in region events
        Log.d(TAG, "Geofence event received: ${event.geofences.size} geofences")
    }

    // -------- Permission Handling --------
    
    override fun onRequestPermissionsResult(
        requestCode: Int, 
        permissions: Array<String>, 
        grantResults: IntArray
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        
        val allGranted = grantResults.isNotEmpty() && 
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            
        mainHandler.post {
            channel.invokeMethod("onPermissionsGranted", listOf(allGranted))
        }
        
        return true
    }

    // -------- Public API Methods --------
    
    fun initialize(@NonNull pluginVersion: String, @NonNull apiKey: String, @NonNull endpoint: String) {
        mainHandler.post {
            try {
                val bundle = Bundle().apply {
                    putString(IALocationManager.EXTRA_API_KEY, apiKey)
                    putString(IALocationManager.EXTRA_API_SECRET, "not-used-in-flutter-plugin")
                    putString("com.indooratlas.android.sdk.intent.extras.wrapperName", "flutter")
                    putString("com.indooratlas.android.sdk.intent.extras.wrapperVersion", pluginVersion)
                    if (endpoint.isNotEmpty()) {
                        putString("com.indooratlas.android.sdk.intent.extras.restEndpoint", endpoint)
                    }
                }
                
                // Clean up existing location manager
                locationManager?.destroy()
                isLocationServiceRunning = false
                
                // Create new location manager
                locationManager = IALocationManager.create(context, bundle)
                
                Log.d(TAG, "IndoorAtlas initialized with plugin version: $pluginVersion")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize IndoorAtlas", e)
            }
        }
    }

    fun requestPermissions() {
        val activity = activityBinding?.activity
        if (activity == null) {
            Log.w(TAG, "No activity available for permission request")
            return
        }

        // Check if we already have all permissions
        val missingPermissions = REQUIRED_PERMISSIONS.filter { permission ->
            ContextCompat.checkSelfPermission(context, permission) != PackageManager.PERMISSION_GRANTED
        }

        if (missingPermissions.isEmpty()) {
            mainHandler.post {
                channel.invokeMethod("onPermissionsGranted", listOf(true))
            }
            return
        }

        // Request missing permissions
        activity.requestPermissions(missingPermissions.toTypedArray(), PERMISSION_REQUEST_CODE)
    }

    fun getTraceId(): String {
        return try {
            locationManager?.extraInfo?.traceId ?: ""
        } catch (e: Exception) {
            Log.w(TAG, "Failed to get trace ID", e)
            ""
        }
    }

    // -------- Positioning Control --------
    
    fun startPositioning() {
        mainHandler.post {
            locationManager?.let { manager ->
                try {
                    manager.registerRegionListener(this)
                    manager.registerOrientationListener(orientationRequest, this)
                    manager.requestLocationUpdates(locationRequest, this)
                    isLocationServiceRunning = true
                    Log.d(TAG, "Positioning started")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start positioning", e)
                }
            }
        }
    }

    fun stopPositioning() {
        mainHandler.post {
            locationManager?.let { manager ->
                try {
                    manager.removeLocationUpdates(this)
                    manager.unregisterOrientationListener(this)
                    manager.unregisterRegionListener(this)
                    isLocationServiceRunning = false
                    Log.d(TAG, "Positioning stopped")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to stop positioning", e)
                }
            }
        }
    }

    fun setPositioningMode(mode: Int?) {
        val priority = when (mode) {
            0 -> IALocationRequest.PRIORITY_HIGH_ACCURACY
            1 -> IALocationRequest.PRIORITY_LOW_POWER
            2 -> IALocationRequest.PRIORITY_CART_MODE
            else -> IALocationRequest.PRIORITY_HIGH_ACCURACY
        }
        locationRequest.priority = priority
        Log.d(TAG, "Positioning mode set to: $mode")
    }

    fun setOutputThresholds(distance: Double?, interval: Double?) {
        val wasRunning = isLocationServiceRunning
        if (wasRunning) stopPositioning()
        
        distance?.let { 
            if (it >= 0) locationRequest.smallestDisplacement = it.toFloat()
        }
        interval?.let { 
            if (it >= 0) locationRequest.fastestInterval = (it * 1000).toLong()
        }
        
        if (wasRunning) startPositioning()
        Log.d(TAG, "Output thresholds set - distance: $distance, interval: $interval")
    }

    fun setSensitivities(orientationSensitivity: Double?, headingSensitivity: Double?) {
        orientationRequest = IAOrientationRequest(
            headingSensitivity ?: 5.0,
            orientationSensitivity ?: 5.0
        )
        
        mainHandler.post {
            locationManager?.let { manager ->
                try {
                    manager.unregisterOrientationListener(this)
                    manager.registerOrientationListener(orientationRequest, this)
                    Log.d(TAG, "Sensitivities updated - heading: $headingSensitivity, orientation: $orientationSensitivity")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to update sensitivities", e)
                }
            }
        }
    }

    // -------- Floor and Indoor Control --------
    
    fun lockIndoors(locked: Boolean) {
        mainHandler.post {
            try {
                locationManager?.lockIndoors(locked)
                Log.d(TAG, "Lock indoors: $locked")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to set lock indoors", e)
            }
        }
    }

    fun lockFloor(floor: Int) {
        mainHandler.post {
            try {
                locationManager?.lockFloor(floor)
                Log.d(TAG, "Floor locked to: $floor")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to lock floor", e)
            }
        }
    }

    fun unlockFloor() {
        mainHandler.post {
            try {
                locationManager?.unlockFloor()
                Log.d(TAG, "Floor unlocked")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to unlock floor", e)
            }
        }
    }

    // -------- Wayfinding Implementation --------
    
    fun startWayfinding(lat: Double?, lon: Double?, floor: Int?, mode: Int? = null) {
        mainHandler.post {
            val manager = locationManager
            if (manager == null) {
                Log.w(TAG, "LocationManager not initialized")
                return@post
            }

            val latitude = lat ?: 0.0
            val longitude = lon ?: 0.0
            val floorLevel = floor ?: 0

            try {
                // Stop any existing wayfinding
                stopWayfindingInternal()

                // Create wayfinding request
                val builder = IAWayfindingRequest.Builder()
                    .withLatitude(latitude)
                    .withLongitude(longitude)
                    .withFloor(floorLevel)

                // Apply mode/tags if specified
                mode?.let { modeValue ->
                    try {
                        when (modeValue) {
                            1 -> {
                                // Try to use EXCLUDE_INACCESSIBLE tag if available
                                val tagsClass = Class.forName("com.indooratlas.android.sdk.IAWayfindingTags")
                                val excludeField = tagsClass.getDeclaredField("EXCLUDE_INACCESSIBLE")
                                val excludeTag = excludeField.get(null)
                                val withTagsMethod = builder.javaClass.getMethod("withTags", excludeTag.javaClass)
                                withTagsMethod.invoke(builder, excludeTag)
                            }
                            2 -> {
                                // Try to use EXCLUDE_ACCESSIBLE_ONLY tag if available
                                val tagsClass = Class.forName("com.indooratlas.android.sdk.IAWayfindingTags")
                                val excludeField = tagsClass.getDeclaredField("EXCLUDE_ACCESSIBLE_ONLY")
                                val excludeTag = excludeField.get(null)
                                val withTagsMethod = builder.javaClass.getMethod("withTags", excludeTag.javaClass)
                                withTagsMethod.invoke(builder, excludeTag)
                            }
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "Wayfinding tags not available in this SDK version: ${e.message}")
                    }
                }

                val request = builder.build()

                // Try listener-based approach first (preferred)
                if (tryStartWayfindingWithListener(manager, request)) {
                    Log.d(TAG, "Wayfinding started with listener approach")
                    return@post
                }

                // Fallback to PendingIntent approach
                if (tryStartWayfindingWithPendingIntent(manager, request)) {
                    Log.d(TAG, "Wayfinding started with PendingIntent approach")
                    return@post
                }

                Log.e(TAG, "No compatible wayfinding method found")

            } catch (e: Exception) {
                Log.e(TAG, "Failed to start wayfinding", e)
            }
        }
    }

    private fun tryStartWayfindingWithListener(
        manager: IALocationManager,
        request: IAWayfindingRequest
    ): Boolean {
        return try {
            // Create listener
            val listener = object : IAWayfindingListener {
                override fun onWayfindingUpdate(route: IARoute) {
                    mainHandler.post {
                        try {
                            channel.invokeMethod("onWayfindingUpdate", listOf(route.toMap()))
                        } catch (e: Exception) {
                            Log.e(TAG, "Error sending wayfinding update", e)
                        }
                    }
                }
            }

            // Find the listener-based method
            val method = manager.javaClass.methods.find { method ->
                method.name == "requestWayfindingUpdates" &&
                        method.parameterTypes.size == 2 &&
                        method.parameterTypes[0].name.contains("IAWayfindingRequest") &&
                        method.parameterTypes[1].name.contains("IAWayfindingListener")
            }

            if (method != null) {
                wayfindingListener = listener
                method.invoke(manager, request, listener)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            Log.w(TAG, "Listener-based wayfinding failed", e)
            false
        }
    }

    private fun tryStartWayfindingWithPendingIntent(
        manager: IALocationManager,
        request: IAWayfindingRequest
    ): Boolean {
        return try {
            // Create PendingIntent
            val intent = Intent(WAYFINDING_ACTION).apply {
                setPackage(context.packageName)
            }

            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                System.identityHashCode(request),
                intent,
                flags
            )

            // Create and register receiver
            val receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    handleWayfindingBroadcast(intent)
                }
            }

            val filter = IntentFilter(WAYFINDING_ACTION)
            context.registerReceiver(receiver, filter)

            // Find the PendingIntent-based method
            val method = manager.javaClass.methods.find { method ->
                method.name == "requestWayfindingUpdates" &&
                        method.parameterTypes.size == 2 &&
                        method.parameterTypes[0].name.contains("IAWayfindingRequest") &&
                        PendingIntent::class.java.isAssignableFrom(method.parameterTypes[1])
            }

            if (method != null) {
                wayfindingPendingIntent = pendingIntent
                wayfindingReceiver = receiver
                method.invoke(manager, request, pendingIntent)
                true
            } else {
                // Clean up if method not found
                try {
                    context.unregisterReceiver(receiver)
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to unregister receiver", e)
                }
                false
            }
        } catch (e: Exception) {
            Log.w(TAG, "PendingIntent-based wayfinding failed", e)
            false
        }
    }

    private fun handleWayfindingBroadcast(intent: Intent?) {
        try {
            if (intent == null) return

            // Try to extract IARoute from different possible keys
            val route = intent.getParcelableExtra<IARoute>("route")
                ?: intent.extras?.let { extras ->
                    extras.keySet().firstNotNullOfOrNull { key ->
                        val value = extras.get(key)
                        if (value is IARoute) value else null
                    }
                }

            if (route != null) {
                mainHandler.post {
                    channel.invokeMethod("onWayfindingUpdate", listOf(route.toMap()))
                }
            } else {
                Log.d(TAG, "No route found in wayfinding broadcast: ${intent.extras?.keySet()}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling wayfinding broadcast", e)
        }
    }

    fun stopWayfinding() {
        mainHandler.post {
            stopWayfindingInternal()
        }
    }

    private fun stopWayfindingInternal() {
        val manager = locationManager ?: return

        try {
            // Stop listener-based wayfinding
            wayfindingListener?.let { listener ->
                val method = manager.javaClass.methods.find { method ->
                    method.name == "removeWayfindingUpdates" &&
                            method.parameterTypes.size == 1 &&
                            method.parameterTypes[0].name.contains("IAWayfindingListener")
                }
                method?.invoke(manager, listener)
                wayfindingListener = null
            }

            // Stop PendingIntent-based wayfinding
            wayfindingPendingIntent?.let { pendingIntent ->
                val method = manager.javaClass.methods.find { method ->
                    method.name == "removeWayfindingUpdates" &&
                            method.parameterTypes.size == 1 &&
                            PendingIntent::class.java.isAssignableFrom(method.parameterTypes[0])
                }
                method?.invoke(manager, pendingIntent)
                wayfindingPendingIntent = null
            }

            // Clean up receiver
            wayfindingReceiver?.let { receiver ->
                try {
                    context.unregisterReceiver(receiver)
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to unregister wayfinding receiver", e)
                }
                wayfindingReceiver = null
            }

            Log.d(TAG, "Wayfinding stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping wayfinding", e)
        }
    }

    // -------- Geofence Management --------
    
    fun requestGeofences(geofenceIds: List<String>) {
        Log.d(TAG, "Geofence monitoring requested for: $geofenceIds")
        // Implementation depends on specific SDK version and requirements
    }

    fun removeGeofences() {
        currentGeofences.clear()
        triggeredGeofenceIds.clear()
        Log.d(TAG, "Geofences removed")
    }

    fun getCurrentGeofences(): List<Map<String, Any?>> {
        return currentGeofences.toList()
    }

    // -------- Helper Methods --------
    
    private fun checkGeofenceTriggers(location: IALocation, geofences: List<IAGeofence>) {
        val newTriggeredIds = mutableSetOf<String>()

        for (geofence in geofences) {
            if (isLocationInGeofence(location, geofence)) {
                newTriggeredIds.add(geofence.id)
            }
        }

        val previousTriggered = triggeredGeofenceIds.toSet()

        // Send ENTER events for newly triggered geofences
        for (geofenceId in newTriggeredIds) {
            if (!previousTriggered.contains(geofenceId)) {
                mainHandler.post {
                    channel.invokeMethod("onGeofenceEvent", listOf(geofenceId, "ENTER"))
                }
            }
        }

        // Send EXIT events for no longer triggered geofences
        for (geofenceId in previousTriggered) {
            if (!newTriggeredIds.contains(geofenceId)) {
                mainHandler.post {
                    channel.invokeMethod("onGeofenceEvent", listOf(geofenceId, "EXIT"))
                }
            }
        }

        triggeredGeofenceIds.clear()
        triggeredGeofenceIds.addAll(newTriggeredIds)
    }

    private fun isLocationInGeofence(location: IALocation, geofence: IAGeofence): Boolean {
        if (geofence.edges.isEmpty()) return false

        val point = doubleArrayOf(location.longitude, location.latitude)
        val polygon = geofence.edges.map { it.reversedArray() }
        return isPointInPolygon(point, polygon)
    }

    private fun isPointInPolygon(point: DoubleArray, polygon: List<DoubleArray>): Boolean {
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

    // -------- Cleanup --------
    
    fun detach() {
        mainHandler.post {
            try {
                stopWayfindingInternal()
                locationManager?.destroy()
                locationManager = null
                Log.d(TAG, "IAFlutterEngine detached")
            } catch (e: Exception) {
                Log.e(TAG, "Error during detach", e)
            }
        }
    }
}

// -------- Extension Functions for Data Conversion --------

private fun IALocation.toMap(): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>(
        "latitude" to latitude,
        "longitude" to longitude,
        "accuracy" to accuracy,
        "altitude" to altitude,
        "heading" to bearing,
        "floorCertainty" to floorCertainty,
        "flr" to floorLevel,
        "velocity" to toLocation().speed,
        "timestamp" to time
    )

    region?.let { region ->
        map["region"] = region.toMap()
        
        region.floorPlan?.let { floorPlan ->
            try {
                val point = floorPlan.coordinateToPoint(latLngFloor)
                map["pix_x"] = point.x
                map["pix_y"] = point.y
            } catch (e: Exception) {
                Log.w("IAFlutterEngine", "Failed to convert coordinate to point", e)
            }
        }
    }

    return map
}

private fun IARegion.toMap(): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>(
        "regionId" to id,
        "timestamp" to timestamp,
        "regionType" to type
    )

    floorPlan?.let { map["floorPlan"] = it.toMap() }
    venue?.let { map["venue"] = it.toMap() }

    return map
}

private fun IAFloorPlan.toMap(): Map<String, Any?> {
    return mapOf(
        "id" to id,
        "name" to (name ?: ""),
        "url" to (url ?: ""),
        "floorLevel" to floorLevel,
        "bearing" to bearing,
        "bitmapWidth" to bitmapWidth,
        "bitmapHeight" to bitmapHeight,
        "widthMeters" to widthMeters,
        "heightMeters" to heightMeters,
        "metersToPixels" to metersToPixels,
        "pixelsToMeters" to pixelsToMeters,
        "bottomLeft" to listOf(bottomLeft.longitude, bottomLeft.latitude),
        "bottomRight" to listOf(bottomRight.longitude, bottomRight.latitude),
        "center" to listOf(center.longitude, center.latitude),
        "topLeft" to listOf(topLeft.longitude, topLeft.latitude),
        "topRight" to listOf(topRight.longitude, topRight.latitude)
    )
}

private fun IAVenue.toMap(): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>(
        "id" to id,
        "name" to name
    )

    if (floorPlans.isNotEmpty()) {
        map["floorPlans"] = floorPlans.map { it.toMap() }
    }

    if (geofences.isNotEmpty()) {
        map["geofences"] = geofences.map { it.toMap() }
    }

    if (poIs.isNotEmpty()) {
        map["pois"] = poIs.map { it.toMap() }
    }

    return map
}

private fun IAGeofence.toMap(): Map<String, Any?> {
    val vertices = edges.flatMap { listOf(it[1], it[0]) }
    val coords = mutableListOf<List<Double>>()
    for (i in vertices.indices step 2) {
        if (i + 1 < vertices.size) {
            coords.add(listOf(vertices[i], vertices[i + 1]))
        }
    }

    return mapOf(
        "type" to "Feature",
        "id" to id,
        "properties" to mapOf(
            "name" to name,
            "floor" to floor,
            "payload" to payload?.toString()
        ),
        "geometry" to mapOf(
            "type" to "Polygon",
            "coordinates" to listOf(coords)
        )
    )
}

private fun IAPOI.toMap(): Map<String, Any?> {
    return mapOf(
        "type" to "Feature",
        "id" to id,
        "properties" to mapOf(
            "name" to name,
            "floor" to floor,
            "payload" to payload?.toString()
        ),
        "geometry" to mapOf(
            "type" to "Point",
            "coordinates" to listOf(location.longitude, location.latitude)
        )
    )
}

private fun IARoute.toMap(): Map<String, Any?> {
    val legs = legs.map { leg ->
        mapOf(
            "begin" to mapOf(
                "latitude" to leg.begin.latitude,
                "longitude" to leg.begin.longitude,
                "floor" to leg.begin.floor
            ),
            "end" to mapOf(
                "latitude" to leg.end.latitude,
                "longitude" to leg.end.longitude,
                "floor" to leg.end.floor
            ),
            "length" to leg.length,
            "direction" to leg.direction,
            "edgeIndex" to (leg.edgeIndex ?: -1)
        )
    }

    return mapOf(
        "legs" to legs,
        "error" to (error?.name ?: "")
    )
}