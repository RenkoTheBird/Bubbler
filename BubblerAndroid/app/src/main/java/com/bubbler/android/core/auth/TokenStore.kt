package com.bubbler.android.core.auth

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * Encrypted access-token storage (KeychainStore on iOS).
 * Uses EncryptedSharedPreferences backed by the Android Keystore.
 */
class TokenStore internal constructor(
    private val prefs: SharedPreferences,
) {
    constructor(context: Context) : this(createEncryptedPrefs(context))

    val currentAccessToken: String?
        get() = loadAccessToken()

    fun saveAccessToken(token: String) {
        val ok = prefs.edit()
            .putString(KEY_ACCESS_TOKEN, token)
            .commit()
        if (!ok) {
            throw TokenStoreException("Could not save your session securely.")
        }
    }

    fun loadAccessToken(): String? = prefs.getString(KEY_ACCESS_TOKEN, null)

    fun deleteAccessToken() {
        prefs.edit().remove(KEY_ACCESS_TOKEN).apply()
    }

    companion object {
        private const val PREFS_NAME = "bubbler_secure_prefs"
        private const val KEY_ACCESS_TOKEN = "access_token"

        fun createEncryptedPrefs(context: Context): SharedPreferences {
            val appContext = context.applicationContext
            val masterKey = MasterKey.Builder(appContext)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()

            return EncryptedSharedPreferences.create(
                appContext,
                PREFS_NAME,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )
        }
    }
}

class TokenStoreException(message: String) : Exception(message)
