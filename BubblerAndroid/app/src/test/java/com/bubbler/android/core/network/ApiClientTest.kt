package com.bubbler.android.core.network

import org.junit.Assert.assertEquals
import org.junit.Test

class ApiClientTest {
    @Test
    fun joinUrl_trimsSlashes() {
        assertEquals(
            "http://10.0.2.2:8000/health",
            ApiClient.joinUrl("http://10.0.2.2:8000/", "/health"),
        )
    }

    @Test
    fun health_json_decodes() {
        val json = ApiClient.defaultJson()
        val health = json.decodeFromString<BackendHealth>(
            """{"status":"ok","database":"connected"}""",
        )
        assertEquals("ok", health.status)
        assertEquals("connected", health.database)
    }
}
