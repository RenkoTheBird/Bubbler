package com.bubbler.android.data.repository

import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.core.network.ApiException
import kotlinx.coroutines.test.runTest
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.LocalDate

class AuthRepositoryTest {
    private lateinit var server: MockWebServer
    private lateinit var repository: AuthRepository

    @Before
    fun setUp() {
        server = MockWebServer()
        server.start()
        val client = ApiClient(baseUrl = server.url("/").toString().trimEnd('/'))
        repository = AuthRepository(client)
    }

    @After
    fun tearDown() {
        server.shutdown()
    }

    @Test
    fun login_sendsFormEncodedEmailAsUsername() = runTest {
        server.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setBody(
                    """{"access_token":"tok","token_type":"bearer","user_id":9}""",
                ),
        )

        val response = repository.login(email = "a@b.com", password = "secret")

        assertEquals("tok", response.accessToken)
        assertEquals("bearer", response.tokenType)
        assertEquals(9, response.userId)

        val recorded = server.takeRequest()
        assertEquals("POST", recorded.method)
        assertEquals("/auth/login", recorded.path)
        assertTrue(
            recorded.getHeader("Content-Type")?.startsWith("application/x-www-form-urlencoded") == true,
        )
        val body = recorded.body.readUtf8()
        assertTrue(body.contains("username=a%40b.com") || body.contains("username=a@b.com"))
        assertTrue(body.contains("password=secret"))
    }

    @Test
    fun register_sendsCalendarDateString() = runTest {
        server.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setBody(
                    """{"access_token":"reg","token_type":"bearer","user_id":2}""",
                ),
        )

        val dob = LocalDate.of(2000, 5, 17)
        val response = repository.register(
            username = "wren",
            email = "wren@example.com",
            password = "hunter2",
            dateOfBirth = dob,
        )

        assertEquals("reg", response.accessToken)
        assertEquals(2, response.userId)

        val recorded = server.takeRequest()
        assertEquals("/auth/register", recorded.path)
        val body = recorded.body.readUtf8()
        assertTrue(body.contains("\"date_of_birth\":\"2000-05-17\""))
        assertTrue(body.contains("\"username\":\"wren\""))
    }

    @Test
    fun login_unauthorized_throws() = runTest {
        server.enqueue(MockResponse().setResponseCode(401).setBody("""{"detail":"bad"}"""))

        try {
            repository.login(email = "a@b.com", password = "nope")
            throw AssertionError("expected Unauthorized")
        } catch (_: ApiException.Unauthorized) {
            // expected
        }
    }
}
