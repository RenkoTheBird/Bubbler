package com.bubbler.android.core.config

/**
 * Backend base URL.
 *
 * Emulator loopback to the host machine is `10.0.2.2`.
 * On a physical device, point this at your machine's LAN IP
 * (e.g. `http://192.168.1.20:8000`).
 */
object ApiConfig {
    const val BASE_URL: String = "http://10.0.2.2:8000"
    const val CONNECT_TIMEOUT_MS: Long = 5_000
    const val READ_TIMEOUT_MS: Long = 15_000
}
