package com.walhallaa.chattest20241220

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/** Only activities that handle map coordinates are discoverable. Selecting a
 * package launches that exact app rather than the device's previous default. */
object MapsBridge {
    private fun mapIntent(id: String, lat: Double, lng: Double, label: String): Intent {
        val point = String.format(Locale.US, "%.6f,%.6f", lat, lng)
        val uri = when (id) {
            "ru.yandex.yandexmaps" -> {
                val reversed = String.format(Locale.US, "%.6f,%.6f", lng, lat)
                "yandexmaps://maps.yandex.ru/?ll=$reversed&pt=$reversed&z=17"
            }
            "com.waze" -> "waze://?ll=$point&navigate=no&zoom=17"
            else -> "geo:$point?q=" + Uri.encode(if (label.isBlank()) point else "$point($label)")
        }
        return Intent(Intent.ACTION_VIEW, Uri.parse(uri))
    }

    @Suppress("DEPRECATION")
    private fun available(activity: Activity): List<Map<String, String>> {
        val pm = activity.packageManager
        val intents = listOf(
            mapIntent("", 0.0, 0.0, ""),
            mapIntent("ru.yandex.yandexmaps", 0.0, 0.0, ""),
            mapIntent("com.waze", 0.0, 0.0, "")
        )
        return intents.flatMap { pm.queryIntentActivities(it, 0) }
            .filter { it.activityInfo.exported && it.activityInfo.packageName != activity.packageName }
            .distinctBy { it.activityInfo.packageName }
            .map { mapOf("id" to it.activityInfo.packageName, "name" to it.loadLabel(pm).toString()) }
            .sortedBy { it["name"]?.lowercase(Locale.ROOT) }
    }

    fun register(activity: Activity, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "monkeyhub/maps")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "available" -> result.success(available(activity))
                    "open" -> {
                        val id = call.argument<String>("id") ?: ""
                        val lat = call.argument<Number>("latitude")?.toDouble()
                        val lng = call.argument<Number>("longitude")?.toDouble()
                        if (lat == null || lng == null || !lat.isFinite() || !lng.isFinite() ||
                            lat !in -90.0..90.0 || lng !in -180.0..180.0 ||
                            available(activity).none { it["id"] == id }) {
                            result.success(false)
                        } else {
                            try {
                                activity.startActivity(mapIntent(id, lat, lng, call.argument<String>("label") ?: "").setPackage(id))
                                result.success(true)
                            } catch (_: Exception) { result.success(false) }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
