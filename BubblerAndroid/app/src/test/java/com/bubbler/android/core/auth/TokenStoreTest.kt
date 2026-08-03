package com.bubbler.android.core.auth

import android.content.SharedPreferences
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

class TokenStoreTest {
    private class MemoryPrefs : SharedPreferences {
        private val map = mutableMapOf<String, String?>()

        override fun getString(key: String?, defValue: String?): String? =
            if (map.containsKey(key)) map[key] else defValue

        override fun edit(): SharedPreferences.Editor = MemoryEditor()

        private inner class MemoryEditor : SharedPreferences.Editor {
            private val pending = mutableMapOf<String, String?>()
            private val removals = mutableSetOf<String>()

            override fun putString(key: String?, value: String?): SharedPreferences.Editor {
                pending[key!!] = value
                return this
            }

            override fun remove(key: String?): SharedPreferences.Editor {
                removals.add(key!!)
                return this
            }

            override fun clear(): SharedPreferences.Editor {
                map.clear()
                return this
            }

            override fun commit(): Boolean {
                removals.forEach { map.remove(it) }
                map.putAll(pending)
                pending.clear()
                removals.clear()
                return true
            }

            override fun apply() {
                commit()
            }

            override fun putStringSet(key: String?, values: MutableSet<String>?) = this
            override fun putInt(key: String?, value: Int) = this
            override fun putLong(key: String?, value: Long) = this
            override fun putFloat(key: String?, value: Float) = this
            override fun putBoolean(key: String?, value: Boolean) = this
        }

        override fun getAll(): MutableMap<String, *> = map.toMutableMap()
        override fun getStringSet(key: String?, defValues: MutableSet<String>?) = defValues
        override fun getInt(key: String?, defValue: Int) = defValue
        override fun getLong(key: String?, defValue: Long) = defValue
        override fun getFloat(key: String?, defValue: Float) = defValue
        override fun getBoolean(key: String?, defValue: Boolean) = defValue
        override fun contains(key: String?) = map.containsKey(key)
        override fun registerOnSharedPreferenceChangeListener(
            listener: SharedPreferences.OnSharedPreferenceChangeListener?,
        ) = Unit
        override fun unregisterOnSharedPreferenceChangeListener(
            listener: SharedPreferences.OnSharedPreferenceChangeListener?,
        ) = Unit
    }

    @Test
    fun saveLoadAndDelete_roundTrip() {
        val store = TokenStore(MemoryPrefs())

        assertNull(store.loadAccessToken())

        store.saveAccessToken("tok-abc")
        assertEquals("tok-abc", store.loadAccessToken())
        assertEquals("tok-abc", store.currentAccessToken)

        store.deleteAccessToken()
        assertNull(store.loadAccessToken())
    }

    @Test
    fun save_throwsWhenCommitFails() {
        val failing = object : SharedPreferences by MemoryPrefs() {
            override fun edit(): SharedPreferences.Editor =
                object : SharedPreferences.Editor {
                    override fun putString(key: String?, value: String?) = this
                    override fun putStringSet(key: String?, values: MutableSet<String>?) = this
                    override fun putInt(key: String?, value: Int) = this
                    override fun putLong(key: String?, value: Long) = this
                    override fun putFloat(key: String?, value: Float) = this
                    override fun putBoolean(key: String?, value: Boolean) = this
                    override fun remove(key: String?) = this
                    override fun clear() = this
                    override fun commit(): Boolean = false
                    override fun apply() = Unit
                }
        }

        val store = TokenStore(failing)
        assertThrows(TokenStoreException::class.java) {
            store.saveAccessToken("tok")
        }
    }
}
