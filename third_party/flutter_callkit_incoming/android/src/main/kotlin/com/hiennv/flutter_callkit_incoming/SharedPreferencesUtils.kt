package com.hiennv.flutter_callkit_incoming

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import com.fasterxml.jackson.core.type.TypeReference


private const val CALLKIT_PREFERENCES_FILE_NAME = "flutter_callkit_incoming"
private var prefs: SharedPreferences? = null
private var editor: SharedPreferences.Editor? = null

private fun initInstance(context: Context) {
    prefs = context.getSharedPreferences(CALLKIT_PREFERENCES_FILE_NAME, Context.MODE_PRIVATE)
    editor = prefs?.edit()
}

fun addBackgroundCallback(context: Context?, pluginHandler: Long, userHandle: Long) {
    putLong(context, "CALLBACK_HANDLE", pluginHandler)
    putLong(context, "CALLBACK_USER_HANDLE", userHandle)
}

fun addCall(context: Context?, data: Data, isAccepted: Boolean = false) {
    val json = getString(context, "ACTIVE_CALLS", "[]")
    val arrayData: ArrayList<Data> = Utils.getGsonInstance()
        .readValue(json, object : TypeReference<ArrayList<Data>>() {})
    val currentData = arrayData.find { it == data }
    if(currentData != null) {
        currentData.isAccepted = isAccepted
    }else {
        data.isAccepted = isAccepted
        arrayData.add(data)
    }
    putString(context, "ACTIVE_CALLS", Utils.getGsonInstance().writeValueAsString(arrayData))
}

fun removeCall(context: Context?, data: Data) {
    val json = getString(context, "ACTIVE_CALLS", "[]")
    Log.d("JSON", json!!)
    val arrayData: ArrayList<Data> = Utils.getGsonInstance()
        .readValue(json, object : TypeReference<ArrayList<Data>>() {})
    arrayData.remove(data)
    putString(context, "ACTIVE_CALLS", Utils.getGsonInstance().writeValueAsString(arrayData))
}

fun removeAllCalls(context: Context?) {
    putString(context, "ACTIVE_CALLS", "[]")
    remove(context, "ACTIVE_CALLS")
}

fun getPluginCallbackHandle(context: Context?): Long? {
    return getLong(context, "CALLBACK_HANDLE", 0L)
}

fun getUserCallback(context: Context?): Long? {
    return getLong(context, "CALLBACK_USER_HANDLE", 0L)
}

fun getDataActiveCalls(context: Context?): ArrayList<Data> {
    val json = getString(context, "ACTIVE_CALLS", "[]")
    return Utils.getGsonInstance()
        .readValue(json, object : TypeReference<ArrayList<Data>>() {})
}

fun getDataActiveCallsForFlutter(context: Context?): ArrayList<Map<String, Any?>> {
    val json = getString(context, "ACTIVE_CALLS", "[]")
    return Utils.getGsonInstance().readValue(json, object : TypeReference<ArrayList<Map<String, Any?>>>() {})
}

fun putLong(context: Context?, key: String, value: Long) {
    if (context == null) return
    initInstance(context)
    editor?.putLong(key, value)
    editor?.commit()
}

fun putString(context: Context?, key: String, value: String?) {
    if (context == null) return
    initInstance(context)
    editor?.putString(key, value)
    editor?.commit()
}

fun getString(context: Context?, key: String, defaultValue: String = ""): String? {
    if (context == null) return null
    initInstance(context)
    return prefs?.getString(key, defaultValue)
}

fun getLong(context: Context?, key: String, defaultValue: Long = 0L): Long? {
    if (context == null) return defaultValue
    initInstance(context)
    return prefs?.getLong(key, defaultValue)
}

fun remove(context: Context?, key: String) {
    if (context == null) return
    initInstance(context)
    editor?.remove(key)
    editor?.commit()
}

fun saveHandle(context: Context?, key: String, handle: Int) {
    if (context == null) return
    initInstance(context)
    editor?.putInt(key, handle)
    editor?.commit()
}

fun getRawHandle(context: Context?, key: String): Int? {
    if (context == null) return null
    initInstance(context)
    return prefs?.getInt(key, 0)
}

// ─── Ended-call registry (MonkeyHub patch) ───────────────────────────────
//
// The ids of calls that ENDED on this device (declined, ended, timed out, or
// dismissed by a `taken` push), each with the time it ended. An INCOMING for
// one of them is dropped, and so is the Telecom connection it would create.
//
// Without it the order of two broadcasts decided whether a phone rang a dead
// call: a dismissal that landed BEFORE its invite (FCM does not order two
// high-priority messages, and the invite's broadcast can sit in the queue
// behind the dismissal's) ended nothing, and the invite then rang its full
// card duration for a call that was already over, with nothing left to stop
// it. Call ids are never reused (both rings derive them from a Convex id), so
// "ended once" is "ended for good"; the TTL only bounds the file.
//
// Its own file and its own lock: the helpers above share one global editor,
// and this is read and written from the FCM worker thread as well as main.

private const val ENDED_CALLS_FILE_NAME = "flutter_callkit_incoming_ended"
private const val ENDED_CALL_TTL_MS = 10 * 60 * 1000L
private val endedCallsLock = Any()

/// Record [id] as ended. apply(), not commit(): the in-memory map, which is
/// what every reader in this process sees, updates synchronously; only the
/// disk write is deferred, so the main thread never waits on flash.
fun markCallEnded(context: Context?, id: String) {
    if (context == null || id.isEmpty()) return
    synchronized(endedCallsLock) {
        val prefs = context.applicationContext
            .getSharedPreferences(ENDED_CALLS_FILE_NAME, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val editor = prefs.edit()
        for ((key, value) in prefs.all) {
            if (value !is Long || now - value > ENDED_CALL_TTL_MS) editor.remove(key)
        }
        editor.putLong(id, now).apply()
    }
}

/// Whether [id] ended on this device within the last ten minutes.
fun isCallEnded(context: Context?, id: String): Boolean {
    if (context == null || id.isEmpty()) return false
    synchronized(endedCallsLock) {
        val at = context.applicationContext
            .getSharedPreferences(ENDED_CALLS_FILE_NAME, Context.MODE_PRIVATE)
            .getLong(id, 0L)
        return at > 0L && System.currentTimeMillis() - at <= ENDED_CALL_TTL_MS
    }
}
