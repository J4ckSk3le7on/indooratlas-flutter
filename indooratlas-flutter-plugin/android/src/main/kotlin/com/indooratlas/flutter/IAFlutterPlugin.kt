package com.indooratlas.flutter

import androidx.annotation.NonNull
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.content.Context
import android.Manifest
import android.util.Log

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener

import com.indooratlas.android.sdk.IALocation
import com.indooratlas.android.sdk.IALocationRequest
import com.indooratlas.android.sdk.IALocationListener
import com.indooratlas.android.sdk.IALocationManager
import com.indooratlas.android.sdk.IARegion

// Conversión de datos nativos a Map para enviar a Dart
private fun IARegion.toMap(): Map<String, Any> = mapOf(
    "regionId" to id,
    "timestamp" to timestamp,
    "type" to type
)

private fun IALocation.toMap(): Map<String, Any> = mapOf(
    "latitude" to latitude,
    "longitude" to longitude,
    "accuracy" to accuracy,
    "floorLevel" to (floorLevel ?: 0),
    "timestamp" to time
)

class IAFlutterEngine(
    context: Context,
    private val channel: MethodChannel
) : IALocationListener, RequestPermissionsResultListener {

    private val handler = Handler(Looper.getMainLooper())
    private val context = context
    private var locationManager: IALocationManager? = null

    companion object {
        private const val PERMISSION_REQUEST_CODE = 444444
    }

    override fun onStatusChanged(provider: String, status: Int, extras: Bundle?) {
        val safeMsg = extras?.getString("message") ?: ""
        handler.post {
            channel.invokeMethod("onStatusChanged", {"status": status, "message": safeMsg})
        }
    }

    override fun onLocationChanged(location: IALocation) {
        val map = location.toMap()
        handler.post {
            channel.invokeMethod("onLocationChanged", map)
        }
    }

    override fun onEnterRegion(region: IARegion) {
        val map = region.toMap()
        handler.post {
            channel.invokeMethod("onEnterRegion", map)
        }
    }

    override fun onExitRegion(region: IARegion) {
        val map = region.toMap()
        handler.post {
            channel.invokeMethod("onExitRegion", map)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray): Boolean {
        // Podrías pasar el resultado a Dart si quieres
        return requestCode == PERMISSION_REQUEST_CODE
    }

    fun initialize(apiKey: String, apiSecret: String) {
        handler.post {
            val extras = Bundle().apply {
                putString(IALocationManager.EXTRA_API_KEY, apiKey)
                putString(IALocationManager.EXTRA_API_SECRET, apiSecret)
            }
            locationManager?.destroy()
            locationManager = IALocationManager.create(context, extras)
        }
    }

    fun startPositioning() {
        handler.post {
            locationManager?.requestLocationUpdates(IALocationRequest.create(), this)
        }
    }

    fun stopPositioning() {
        handler.post {
            locationManager?.removeLocationUpdates(this)
        }
    }

    fun detach() {
        handler.post {
            locationManager?.destroy()
            channel.setMethodCallHandler(null)
        }
    }
}

class IAFlutterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var engine: IAFlutterEngine
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.indooratlas.flutter")
        channel.setMethodCallHandler(this)
        engine = IAFlutterEngine(binding.applicationContext, channel)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        engine.detach()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        engine.activityBinding = binding
    }

    override fun onDetachedFromActivityForConfigChanges() { engine.activityBinding = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        engine.activityBinding = binding
    }
    override fun onDetachedFromActivity() { engine.activityBinding = null }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when(call.method) {
            "initialize" -> {
                val key = call.argument<String>("apiKey")
                val secret = call.argument<String>("apiSecret")
                if (key != null && secret != null) {
                    engine.initialize(key, secret)
                    result.success(null)
                } else result.error("INVALID_ARGS", "apiKey or apiSecret missing", null)
            }
            "startPositioning" -> { engine.startPositioning(); result.success(null) }
            "stopPositioning" -> { engine.stopPositioning(); result.success(null) }
            else -> result.notImplemented()
        }
    }
}
