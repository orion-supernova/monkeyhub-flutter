package com.walhallaa.chattest20241220

import android.app.Activity
import android.os.CancellationSignal
import androidx.core.content.ContextCompat
import androidx.credentials.CreateCredentialResponse
import androidx.credentials.CreatePasswordRequest
import androidx.credentials.CredentialManager
import androidx.credentials.CredentialManagerCallback
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import androidx.credentials.GetPasswordOption
import androidx.credentials.PasswordCredential
import androidx.credentials.exceptions.CreateCredentialCancellationException
import androidx.credentials.exceptions.CreateCredentialException
import androidx.credentials.exceptions.GetCredentialException
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * `monkeyhub/continue_credential`: the Android half of "Continue as @name"
 * (Dart: `lib/auth/continue_store.dart`, backend: `continueKeys.ts`).
 *
 * The continue key is saved as a password credential, username = the
 * MonkeyHub handle, password = the key, into Google Password Manager through
 * Credential Manager. GPM syncs it to every device of the same Google account,
 * so a fresh install on the account's tablet finds it.
 *
 *  * `get`  -> {username, key} or null. Shows the system "Sign in as" sheet,
 *    which IS the "continue with this account?" question: picking the entry
 *    continues, dismissing it means "use something else". With
 *    `preferImmediatelyAvailableCredentials` there is no sheet at all when
 *    nothing is saved.
 *  * `save` {username, key} -> "saved" | "declined" | "unavailable". Shows
 *    the system save prompt. "unavailable" (no provider, no activity in
 *    front, anything else) means it is worth asking again another time.
 */
object ContinueCredentialBridge {
    fun register(activity: Activity, engine: FlutterEngine) {
        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, "monkeyhub/continue_credential")
        ch.setMethodCallHandler { call, result ->
            val manager = CredentialManager.create(activity)
            when (call.method) {
                "get" -> {
                    val request = GetCredentialRequest.Builder()
                        .addCredentialOption(GetPasswordOption())
                        .setPreferImmediatelyAvailableCredentials(true)
                        .build()
                    manager.getCredentialAsync(
                        activity,
                        request,
                        CancellationSignal(),
                        ContextCompat.getMainExecutor(activity),
                        object : CredentialManagerCallback<GetCredentialResponse, GetCredentialException> {
                            override fun onResult(response: GetCredentialResponse) {
                                val c = response.credential
                                if (c is PasswordCredential) {
                                    result.success(mapOf("username" to c.id, "key" to c.password))
                                } else {
                                    result.success(null)
                                }
                            }

                            override fun onError(e: GetCredentialException) {
                                // Nothing saved, the sheet dismissed, or no
                                // provider on this device (no Play services).
                                result.success(null)
                            }
                        },
                    )
                }
                "save" -> {
                    val username = call.argument<String>("username")
                    val key = call.argument<String>("key")
                    if (username.isNullOrEmpty() || key.isNullOrEmpty()) {
                        result.success("unavailable")
                        return@setMethodCallHandler
                    }
                    manager.createCredentialAsync(
                        activity,
                        CreatePasswordRequest(username, key),
                        CancellationSignal(),
                        ContextCompat.getMainExecutor(activity),
                        object : CredentialManagerCallback<CreateCredentialResponse, CreateCredentialException> {
                            override fun onResult(response: CreateCredentialResponse) {
                                result.success("saved")
                            }

                            override fun onError(e: CreateCredentialException) {
                                result.success(
                                    if (e is CreateCredentialCancellationException) "declined" else "unavailable",
                                )
                            }
                        },
                    )
                }
                else -> result.notImplemented()
            }
        }
    }
}
